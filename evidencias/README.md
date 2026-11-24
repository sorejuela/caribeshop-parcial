# Evidencias

Esta carpeta no contiene resultados de Azure inventados. Crear las subcarpetas al ejecutar `docs/pruebas.md`:

- `configuracion/`: instancias/zonas, IPs, roles, respuesta de `/secret`, auditoría y alerta.
- `p1/`: CSV/HTML de capacidad y escalamiento; gráfico y Activity Log.
- `p2/`: peticiones, marcas de tiempo, observación de instancias y resúmenes de fallas.
- `p3/`: rechazo de red, salida bloqueada y error de Policy.

Revisar que ninguna captura o archivo contenga secretos, tokens o estados Terraform antes de subirlos. Los ensayos locales se guardan en `evidencias/local/`, ignorado por Git, y no sustituyen las pruebas de Azure.
