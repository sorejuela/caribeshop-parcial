# Pruebas y evidencias

Ejecutar desde la raíz del repositorio, únicamente contra el laboratorio propio. Mantener la hora del generador sincronizada. Los CSV usan epoch UTC; las capturas del portal también deben indicar UTC. No copiar tokens, valores de secretos ni estados Terraform a `evidencias/`.

## Preparación

```bash
APP_URL=$(terraform -chdir=infra output -raw app_url)
RG=$(terraform -chdir=infra output -raw resource_group)
VMSS=$(terraform -chdir=infra output -raw vmss_name)
VMSS_ID=$(terraform -chdir=infra output -raw vmss_id)
KV=$(terraform -chdir=infra output -raw key_vault_name)
PRINCIPAL=$(terraform -chdir=infra output -raw principal_id)
mkdir -p evidencias/p1 evidencias/p2 evidencias/p3 evidencias/configuracion
az vmss list-instances -g "$RG" -n "$VMSS" \
  --query '[].{id:instanceId,zona:zones,nombre:osProfile.computerName}' \
  -o json > evidencias/configuracion/instancias.json
az vmss nic list -g "$RG" --vmss-name "$VMSS" \
  --query '[].ipConfigurations[].{privada:privateIPAddress,publica:publicIPAddress}' \
  -o json > evidencias/configuracion/red.json
az role assignment list --assignee "$PRINCIPAL" --all \
  -o json > evidencias/configuracion/roles.json
curl --fail "$APP_URL/secret" > evidencias/configuracion/lectura-secreto.json
```

Ejecutar `pruebas/auditoria.kql` en Logs, sustituyendo el principal real. Guardar resultados de `SecretGet` y el historial de autoscale. Puede haber demora de ingestión. La lectura local con mocks no sirve como evidencia S3/S6.

## P1 · Capacidad de una instancia

```bash
terraform -chdir=infra apply -var='capacity_test=true'
```

Esperar hasta que `az vmss list-instances` muestre una sola VM sana. `ignore_changes` evita que Terraform fuerce la capacidad; Azure Monitor debe reconciliar el perfil min=default=max=1. Si tarda, documentar y fijar una vez con `az vmss scale -g "$RG" -n "$VMSS" --new-capacity 1`. Esa preparación manual no es evidencia de autoscale.

Ejecutar ensayos independientes de 3–5 minutos, aumentando `-u` y usando un prefijo distinto en cada corrida:

```bash
.venv/bin/python -m locust -f locustfile.py --headless --host "$APP_URL" \
  -u 10 -r 2 -t 5m --csv evidencias/p1/capacidad-10 --csv-full-history \
  --html evidencias/p1/capacidad-10.html
```

Repetir, por ejemplo, con 20, 40, 80 usuarios, hasta observar p95 >1000 ms. Registrar RPS sostenidos, p95, errores, CPU y créditos B. No tratar el pico de RPS como capacidad sostenible. Medir también el último nivel con p95 <500 ms: lo exige la pregunta sobre 300 RPS.

Restaurar el perfil y **confirmar dos instancias sanas** antes de continuar:

```bash
terraform -chdir=infra apply -var='capacity_test=false'
```

## P1 · Autoscale durante 30 minutos

En una terminal, iniciar observación del VMSS:

```bash
.venv/bin/python pruebas/observar.py --group "$RG" --vmss "$VMSS" \
  --seconds 1860 --output evidencias/p1/instancias.csv
```

En otra, definir `PEAK_USERS` según la capacidad medida (100 es un punto de partida, no una predicción):

```bash
PERFIL=escalonado PEAK_USERS=100 .venv/bin/python -m locust \
  -f locustfile.py --headless --host "$APP_URL" \
  --csv evidencias/p1/escalamiento --csv-full-history \
  --html evidencias/p1/escalamiento.html
```

El perfil dura 30 minutos y termina por sí mismo. Exigir aumento y reducción reales de instancias; si no ocurre, analizar CPU/cuota/créditos, ajustar carga y repetir. Exportar también el historial de Azure Monitor y las métricas CPU/Health Probe Status. El muestreo de `observar.py` separa VMs existentes, capacidad configurada y VMs que Azure informa sanas (`healthy`). Contrastar también con las respuestas recibidas: la cantidad por sí sola no demuestra disponibilidad.

```bash
MPLCONFIGDIR=.local/matplotlib .venv/bin/python pruebas/analizar.py carga \
  --history evidencias/p1/escalamiento_stats_history.csv \
  --instances evidencias/p1/instancias.csv --output evidencias/p1/escalamiento.png
az monitor activity-log list --resource-group "$RG" --offset 2h \
  -o json > evidencias/p1/actividad.json
```

## P2 · Falla lógica y abrupta

Hacer las dos pruebas por separado, comenzando cada una con dos instancias sanas y capacidad estable. Guardar un CSV de observación por prueba. La carga moderada debe permitir que una sola instancia atienda el tráfico sin saturarse; usar la medición P1 para elegir los usuarios.

```bash
REQUEST_LOG=evidencias/p2/logica-peticiones.csv .venv/bin/python -m locust \
  -f locustfile.py --headless --host "$APP_URL" -u 5 -r 1 -t 20m \
  --csv evidencias/p2/logica --csv-full-history --html evidencias/p2/logica.html
```

En otra terminal, elegir el ID actual con `az vmss list-instances -g "$RG" -n "$VMSS" -o table`. Esperar que ambas instancias hayan recibido tráfico en el CSV y ejecutar:

```bash
INSTANCE_ID=REEMPLAZAR
az vmss run-command invoke -g "$RG" -n "$VMSS" --instance-id "$INSTANCE_ID" \
  --command-id RunShellScript --scripts \
  'touch /var/lib/caribeshop/unhealthy; date -u +%s; hostname; curl -s -o /dev/null -w "health=%{http_code}\n" http://127.0.0.1:8080/health' \
  -o json > evidencias/p2/inyeccion-logica.json
```

El timestamp impreso dentro de la VM es el inicio efectivo; la llamada Run Command puede tardar. `/health` y `/work` devuelven 503 hasta que Azure retire la instancia del tráfico. Conservar el hostname y el ID; esperar la reparación **Replace** y capturar el nuevo ID. `PT10M` es la gracia tras cambios de estado, no una promesa de reparación exactamente diez minutos después de la falla. No reponer manualmente la marca si se quiere probar E4. Si las reparaciones quedan suspendidas, recoger el diagnóstico en vez de afirmar recuperación automática.

Para la falla abrupta, repetir Locust y el observador con nombres `abrupta-*`. Registrar hora antes de enviar la eliminación y al completar, y contrastar con Activity Log:

```bash
date -u +%s > evidencias/p2/abrupta-inicio.txt
az vmss delete-instances -g "$RG" -n "$VMSS" --instance-ids "$INSTANCE_ID"
date -u +%s > evidencias/p2/abrupta-eliminada.txt
```

Una eliminación explícita puede reducir `sku.capacity`. No equivale a una VM no sana: la reparación automática no garantiza reemplazar un recurso eliminado deliberadamente. Observar si autoscale repone el mínimo; si no, registrar el límite observado y restaurar con `az vmss scale --new-capacity 2`. **Separar esa restauración manual del tiempo de recuperación automática** y explicarlo en el informe. Confirmar recuperación de salud y tráfico, no solamente la cantidad de VMs.

Calcular el porcentaje dentro de una ventana declarada, no sobre toda la corrida. Para falla lógica se puede usar la ventana desde inyección hasta que ambas instancias estén sanas; además reportar una ventana fija de 60 s para comparar:

```bash
.venv/bin/python pruebas/analizar.py falla \
  --requests evidencias/p2/logica-peticiones.csv \
  --start EPOCH_INYECCION --end EPOCH_FIN --instance HOSTNAME_AFECTADO \
  > evidencias/p2/logica-resumen.json
```

`last_affected_response_seconds` es la última respuesta observada del nodo afectado desde la inyección. Es una aproximación al retiro del tráfico: incluye la duración de la petición y no identifica conexiones que fallaron sin respuesta. Documentar esa limitación. Errores = peticiones HTTP fallidas + errores de conexión registrados por Locust.

## P3 · Seguridad

1. Desde la IP autorizada, confirmar el rol del operador y una lectura del secreto usando `az keyvault secret show --vault-name "$KV" --name demo-token --query id -o tsv`. Solo se imprime el identificador, nunca el valor. Luego, con **la misma identidad** en una red no autorizada (por ejemplo, Cloud Shell fuera de la subred), ejecutar el mismo comando y guardar el error `ForbiddenByFirewall`. Un error genérico de RBAC no demuestra el bloqueo de red. En esta ejecución se aisló la variable retirando temporalmente solo la IP del operador del firewall, repitiendo la lectura con la misma identidad y restaurando la regla en un bloque `finally`. Se comprobó lectura válida antes y después; la subred permaneció autorizada.
2. Ejecutar desde una VM mediante Run Command:

```bash
az vmss run-command invoke -g "$RG" -n "$VMSS" --instance-id "$INSTANCE_ID" \
  --command-id RunShellScript --scripts \
  'curl --connect-timeout 5 --max-time 10 -I https://example.com; printf "exit=%s\n" "$?"' \
  -o json > evidencias/p3/salida-bloqueada.json
```

Esperar timeout y contrastar con NSG efectivo; un error DNS o de certificado no prueba filtrado TCP. Key Vault debe seguir funcionando. La salida a las etiquetas de Azure permitidas sigue siendo un riesgo residual.

3. Intentar un Storage con Shared Key dentro del grupo protegido, después de la propagación de la política:

```bash
az storage account create --name NOMBREGLOBALUNICODEPRUEBA \
  --resource-group "$RG" --location REGION_REAL --sku Standard_LRS \
  --allow-shared-key-access true --allow-blob-public-access false \
  > evidencias/p3/policy-stdout.txt 2> evidencias/p3/policy-error.txt
```

Debe fallar con `RequestDisallowedByPolicy`. Si se crea, la prueba falló: eliminar **solo la cuenta de prueba recién creada**, esperar/corregir la asignación y repetir. Nunca usar un recurso preexistente para esta prueba.

Finalmente guardar captura de `Health Probe Status`, alerta activada o correo recibido, consulta KQL de SecretGet, dos PR cerrados y ejecución de Checkov. Destruir los recursos cuando se hayan recogido las evidencias y grabado el video.
