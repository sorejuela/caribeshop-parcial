# Estimación previa al despliegue

Consulta del 23 de noviembre de 2026. Región Canada Central, Linux, pago por uso, USD. Es una estimación de consumo, no una factura ni un límite automático de Azure.

| Componente | Tarifa consultada | Dos instancias | Tres instancias |
|---|---:|---:|---:|
| B2pls_v2, 2 vCPU/4 GiB | 0,0368 USD/h por VM | 0,0736 USD/h | 0,1104 USD/h |
| Load Balancer Standard, hasta 5 reglas | 18,25 USD/mes, 730 h | 0,025 USD/h | 0,025 USD/h |
| IPv4 pública Standard estática | 0,005 USD/h | 0,005 USD/h | 0,005 USD/h |
| Subtotal anterior | | **0,1036 USD/h** | **0,1404 USD/h** |

Faltan en ese subtotal discos Standard LRS, almacenamiento ZRS del estado, operaciones, datos procesados por el balanceador, salida de datos, Key Vault, logs y alertas. El balanceador anuncia además 0,005 USD por GB procesado. No presentar el subtotal como costo total.

Con 730 h al mes, el subtotal sería 75,63 USD con dos VMs o 102,49 USD con tres, antes de esos componentes adicionales. Mantener el mínimo de dos VMs durante dos horas supone 0,2072 USD de este subtotal; el máximo de tres durante dos horas, 0,2808 USD. Destruir el laboratorio al acabar evita seguir consumiendo crédito. Completar la estimación mensual en la calculadora cuando se prepare el informe final.

Fuentes públicas de la calculadora de Microsoft, moneda USD y región `canada-central`:

- [VMs](https://azure.microsoft.com/api/v2/pricing/virtual-machines-base/calculator/?culture=en-us&currency=USD): oferta `linux-b2plsv2-standard`.
- [Balanceador](https://azure.microsoft.com/api/v2/pricing/load-balancer/calculator/?culture=en-us&currency=USD): `rules-included` y `data-processed`.
- [IP pública](https://azure.microsoft.com/api/v2/pricing/ip-addresses/calculator/?culture=en-us&currency=USD): `standard-static-arm`.
- [Calculadora interactiva](https://azure.microsoft.com/pricing/calculator/).
