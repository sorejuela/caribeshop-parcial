# D1 · Pipeline bloqueante

Ejecuciones reales del 23 de noviembre de 2026 (America/Bogota).

- [Código base validado](https://github.com/sorejuela/caribeshop-parcial/actions/runs/45324725559): formato, validate de ambos proyectos, Checkov y cuatro pruebas HTTP correctos.
- [PR 1: fallo deliberado](https://github.com/sorejuela/caribeshop-parcial/pull/1): añadió `azurerm_network_security_rule.insecure_demo`, con SSH desde Internet. Cerrado sin integrar; nunca se aplicó en Azure.
- [Ejecución rechazada](https://github.com/sorejuela/caribeshop-parcial/actions/runs/45324830774): `CKV_AZURE_10` falló sobre esa regla. Formato y validación de Terraform pasaron; la etapa de seguridad detuvo el pipeline.
- [PR 2: corrección integrada](https://github.com/sorejuela/caribeshop-parcial/pull/2), con [pipeline correcto](https://github.com/sorejuela/caribeshop-parcial/actions/runs/45325306653). Ambos PR están cerrados.

La corrección elimina completamente la regla insegura. No añade un skip, no modifica la severidad ni habilita soft-fail. El PR de corrección conserva los dos commits para revisar el antes y el después.

Estas ejecuciones prueban D1, no las propiedades del despliegue en Azure. Los resultados locales de carga tampoco sustituyen P1/P2/P3.
