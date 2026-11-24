# Riesgos aceptados

Excepciones acotadas al laboratorio; revisar antes de reutilizarlo en producción. Cada identificador omitido tiene un comentario junto al recurso afectado.

| Riesgo | Checkov | Motivo y posible impacto | Mitigación |
|---|---|---|---|
| R1 | CKV_AZURE_33 | No se usa Queue; no hay logs de ese servicio. | Shared Key deshabilitado, RBAC y único contenedor privado. Activar auditoría si se usa Queue. |
| R2 | CKV_AZURE_59, CKV2_AZURE_33 | Backend con endpoint público; sin Private Endpoint. La IP autorizada podría ser comprometida. | Firewall Deny, una IPv4, Entra ID, TLS; para producción, red privada y runner privado. |
| R3 | CKV_AZURE_206 | ZRS replica entre zonas, no regiones. Una falla regional puede impedir operar Terraform. | Versiones y soft delete; migrar a GZRS y diseñar recuperación regional si se requiere. |
| R4 | CKV_AZURE_36 | No se admite el bypass general de servicios Microsoft. Es una restricción adicional, no una apertura. | Solo operador autorizado; añadir excepciones concretas si aparece una necesidad real. |
| R5 | CKV2_AZURE_1 | Claves de cifrado administradas por Microsoft, sin CMK. Menor control del ciclo de la clave. | Cifrado de infraestructura habilitado; CMK con vault independiente para producción. |
| R6 | CKV2_AZURE_21 | Sin auditoría del plano de datos de Blob; una lectura del estado puede no quedar registrada. | RBAC limitado y firewall. Versionado/soft delete protegen recuperación, no detectan lecturas; añadir diagnósticos de Blob para producción. |
| R7 | CKV2_AZURE_32 | Key Vault usa service endpoint en lugar de Private Endpoint, conforme a la referencia del taller. | Firewall Deny con subred e IP /32, HTTPS y RBAC; no bypass general. |

Otros límites que Checkov no elimina:

- HTTP público y `/work` sin autenticación: solo datos sintéticos, servicio de laboratorio temporal; el trabajo CPU está fijado en servidor. Para producción, TLS, límites de peticiones y WAF. No enviar contraseñas ni información de clientes por esta app.
- `Storage` y `AzureKeyVault` abarcan destinos de otros clientes: el NSG evita Internet arbitrario, pero no elimina toda vía de exfiltración hacia esos servicios. Una instancia comprometida puede leer el secreto autorizado y acceder a esos destinos; se necesita un proxy/firewall con destinos específicos para restringir más.
- Dos zonas dentro de una sola región: no cubre una caída regional. Añadir otra región exige replicación y enrutamiento global, con costo adicional.
- `/health` comprueba el proceso local, no Key Vault. El endpoint de secreto puede fallar aunque la sonda sea sana. Se evita así retirar simultáneamente todas las VMs ante un incidente externo.
- Ubuntu con versión fijada no se actualiza desde Internet al arrancar. El filtrado de salida lo impide deliberadamente. Actualizar periódicamente la imagen base y volver a desplegarla; revisar la versión antes de cada sesión.
- La serie B puede agotar créditos CPU y distorsionar capacidad/autoscale. Registrar créditos restantes o elegir un SKU sin créditos antes de las pruebas sostenidas.
- B2pls_v2 admite cifrado en host, pero anuncia `TrustedLaunchDisabled=True`: no se habilitan Secure Boot/vTPM en este laboratorio. Una imagen alterada no tendría esa verificación de arranque. Se usa Ubuntu oficial fijado, proceso sin root y acceso restringido; migrar a un tamaño compatible cuando exista disponibilidad/cuota.
- El valor generado del secreto queda en el estado y sus versiones. Una filtración requiere rotarlo y revisar accesos; marcarlo `sensitive` no cifra el estado por sí mismo.
