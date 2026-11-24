# Estimación de costos

Tarifas consultadas el 23 de noviembre de 2026 en Colombia (24 de noviembre UTC). Canada Central, Linux, USD, pago por uso, sin reservas ni descuento de estudiante. Las tarifas verificables de la calculadora se conservan en `evidencias/costos/tarifas.json`. Es una estimación, no una factura ni un límite automático de Azure.

## Escenario mensual de referencia

730 horas, tres B2pls_v2 disponibles todo el mes, un disco Standard HDD S4 de hasta 32 GiB por VM, 100 GB procesados por el LB, hasta 100 GB de salida a Internet, 10 GB de logs, 100.000 operaciones de secretos, 1 GiB de estado incluyendo versiones, 10.000 escrituras y 10.000 lecturas Blob, un millón de operaciones de disco y una alerta con menos de 1.000 correos. Son supuestos de presupuesto, no tráfico mensual medido.

| Concepto | Cálculo | USD/mes |
|---|---|---:|
| Tres VMs B2pls_v2 | 3 × 730 × 0,0368 | 80,5920 |
| Tres discos S4 | 3 × 1,69 | 5,0700 |
| Balanceador Standard, hasta cinco reglas | Tarifa mensual | 18,2500 |
| IPv4 Standard estática | 730 × 0,005 | 3,6500 |
| Datos del balanceador | 100 × 0,005 | 0,5000 |
| Operaciones de disco | 100 × 0,0005 por 10.000 | 0,0500 |
| Blob Hot ZRS y versiones | 1 × 0,025 | 0,0250 |
| Operaciones Blob | 0,0688 escritura + 0,0044 lectura | 0,0732 |
| Key Vault, secretos Standard | 10 × 0,03 por 10.000 | 0,3000 |
| Log Analytics | (10 − 5 incluidos) × 2,76 | 13,8000 |
| Alerta métrica y correos | Dentro de cantidades incluidas | 0,0000 |
| Salida a Internet | Dentro de primeros 100 GB incluidos | 0,0000 |
| **Total del escenario** | | **122,3102** |

Los tramos gratuitos se suponen disponibles en la cuenta; otros recursos pueden consumirlos. No se incluye soporte, impuestos, dominio, WAF, TLS administrado ni base de datos, porque no se desplegaron. La retención de logs es de 30 días. El límite diario de ingestión de 1 GB es una protección operativa, no un presupuesto exacto. El costo aumenta con tráfico, logs, versiones u operaciones mayores a los supuestos.

## Efecto de autoscale

Con `c = 0,0368 + 1,69/730 = 0,039115 USD por VM-hora` y manteniendo los demás supuestos constantes:

- Tres VMs fijas: `2190 × c + 36,6482 = 122,31 USD/mes`.
- Dos VMs fijas: `1460 × c + 36,6482 = 93,76 USD/mes`.
- Escenario variable: dos VMs durante 600 h y tres durante 130 h. `1590 × c + 36,6482 = 98,84 USD/mes`.

El escenario variable ahorra **23,47 USD/mes (19,2 %)** frente al pico fijo. La distribución de 600/130 horas es una hipótesis explícita; la prueba de 30 minutos no demuestra ese patrón mensual. El mínimo de dos VMs limita el ahorro. La serie B requiere revisar créditos CPU antes de usar esta estimación para carga sostenida de producción.

## Sesión de laboratorio y presupuesto

El usuario autorizó hasta **5 USD**, con destrucción al terminar. VMs, balanceador e IP suman 0,1036 USD/h con dos VMs o 0,1404 USD/h con tres; discos, logs, almacenamiento y operaciones se añaden. No confundir este subtotal horario con el total de la tabla. La facturación de Azure puede aparecer con retraso; registrar por separado el costo observado y la estimación temporal.

## Fuentes oficiales

- [Calculadora de Azure](https://azure.microsoft.com/pricing/calculator/).
- [Tarifas de VMs](https://azure.microsoft.com/api/v2/pricing/virtual-machines-base/calculator/?culture=en-us&currency=USD), oferta `linux-b2plsv2-standard`.
- [Balanceador](https://azure.microsoft.com/api/v2/pricing/load-balancer/calculator/?culture=en-us&currency=USD) e [IP pública](https://azure.microsoft.com/api/v2/pricing/ip-addresses/calculator/?culture=en-us&currency=USD).
- [Discos administrados](https://azure.microsoft.com/api/v2/pricing/managed-disks/calculator/?culture=en-us&currency=USD), ofertas `standardhdd-s4` y `transactions-hdd`.
- [Blob Storage](https://azure.microsoft.com/en-us/pricing/details/storage/blobs/), tablas Hot ZRS, namespace plano.
- [Key Vault](https://azure.microsoft.com/api/v2/pricing/key-vault/calculator/?culture=en-us&currency=USD) y [Monitor](https://azure.microsoft.com/api/v2/pricing/monitor/calculator/?culture=en-us&currency=USD).
- [Transferencia de datos](https://azure.microsoft.com/en-us/pricing/details/bandwidth/).

## Segunda región: costo base adicional

Como referencia para la pregunta de falla regional, las mismas tarifas oficiales en East US 2 dan B2pls_v2 a 0,0336 USD/h y disco S4 a 1,536 USD/mes. Dos VMs (49,056), dos discos (3,072), LB (18,25), IP (3,65), dos endpoints Azure de Traffic Manager (0,72) y un millón de consultas DNS (0,54) suman **75,29 USD/mes adicionales de base**. Se añaden operaciones de vault, logs y transferencia según uso; el tramo gratuito de logs no se duplica por crear otra región. Esta alternativa no está desplegada ni valida disponibilidad o cuota allí. Fuente adicional: [Traffic Manager](https://azure.microsoft.com/api/v2/pricing/traffic-manager/calculator/?culture=en-us&currency=USD).
