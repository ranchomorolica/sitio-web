# Estudio: acceso y control de usuarios en subastas ganaderas en línea

**Para:** Rancho Morolica · **Fecha:** septiembre 2026

Comparación de cómo manejan el acceso de compradores y administradores las
subastas ganaderas que usted me pidió estudiar, y qué de eso le conviene
adoptar. Al final está la lista de lo que le falta, priorizada.

> Nota honesta: algunos reglamentos en PDF (Asoregan, Proagan, Subastar) no los
> pude abrir directamente porque mi entorno de trabajo tiene bloqueado el acceso
> a esos sitios. Lo que aparece aquí viene de fuentes secundarias confiables y de
> los resúmenes públicos de esos mismos reglamentos. Antes de copiar una cifra
> exacta (una comisión, un plazo), confírmela en el documento original.

---

## 1. Qué hace cada una

| Plataforma | País | Modelo de acceso | Lo distintivo |
|---|---|---|---|
| **Subacasanare** | Colombia (Yopal) | Vinculación formal previa: formulario de persona natural/jurídica + **pagaré firmado** + autorización para consultar centrales de riesgo | El comprador queda respaldado por un título valor antes de pujar |
| **Subastar S.A.** | Colombia | Vinculación + **cupo de crédito asignado** por cliente | Si compra por encima de su cupo, debe pagar por transferencia antes de retirar |
| **Asoregan** | Colombia | Registro + pago de contado | **Comisión del comprador: 1%**, pagada el mismo día. Retiro al día siguiente |
| **Proagan** | Colombia | Vinculación + cámara de comercio (jurídicas) | Reporta a Datacrédito a quien no paga a tiempo |
| **Koprix** | Colombia | 100% virtual, registro en plataforma | **Custodia del dinero**: retiene el pago hasta que ambas partes confirmen la entrega. Solo transferencias, nunca efectivo |
| **Suganar** | Colombia (Urabá) | App propia (*Suganapp*) + transmisión en YouTube | 3 subastas por semana, ~2.000 cabezas semanales |
| **El Corral (Tipitapa)** | Nicaragua | **No tiene plataforma de pujas en línea** | Opera con subasta física + Facebook, Instagram y TikTok para difusión |

**Lo primero que salta a la vista:** usted ya está por encima de El Corral de
Tipitapa, que es puro remate físico con redes sociales. Y en capacidad técnica
está a la altura de las colombianas. Donde está por debajo es en **el filtro
del comprador antes de dejarlo pujar**, que es justo donde ellas se protegen.

---

## 2. El hallazgo más importante: cómo se protegen del que no paga

Ninguna de las subastas colombianas serias deja pujar a alguien solo porque se
registró en la página. Todas exigen una **vinculación previa** con respaldo legal:

1. **Pagaré firmado en blanco.** Antes de la primera puja, el comprador firma un
   pagaré con carta de instrucciones. Si no paga, la subasta lo llena por el
   monto adeudado y lo cobra judicialmente. Esto es lo más fuerte que tienen.
2. **Autorización para consultar centrales de riesgo.** Antes de aprobarlo,
   revisan su historial crediticio. Y si incumple, lo reportan.
3. **Cupo de crédito por cliente.** A cada comprador se le asigna un techo según
   su historial. Por debajo del cupo puede llevarse el ganado y pagar después;
   por encima, paga por adelantado.
4. **Lista negra compartida del gremio.** Reportan al incumplido a *Asosubastas*,
   la asociación de subastas. Quien queda mal en una, queda mal en todas.
5. **El incumplido paga la diferencia.** Si no paga y el ganado se vuelve a
   rematar más barato, la pérdida se la cobran a él.

Su depósito de L10,000 cumple una función parecida pero más débil: cubre bien a
un comprador chico, pero no a uno que se adjudica L500,000 en ganado y se
arrepiente. **Esa es su mayor exposición hoy.**

---

## 3. Acceso del USUARIO: lo que debe tener una subasta en línea

Marcado con ✅ lo que Rancho Morolica ya tiene funcionando, ❌ lo que falta.

### Entrada a la cuenta
- ✅ Registro con nombre, teléfono, correo y contraseña
- ✅ Inicio de sesión disponible en todo momento (sección "Mi cuenta"), no solo el día del remate
- ✅ Recuperación de contraseña por correo
- ✅ Verificación en dos pasos opcional (código del teléfono)
- ✅ Aviso claro de qué pasó al registrarse y errores explicados en español
- ✅ Detección de teléfono ya registrado, para que nadie abra cuentas duplicadas
- ❌ Cierre de sesión automático tras un rato de inactividad
- ❌ Aviso al correo cuando alguien entra a su cuenta desde un dispositivo nuevo

### Identificación de la persona (KYC)
- ✅ Número de identidad, dirección, estado civil
- ✅ Foto del documento por ambos lados, guardada en espacio privado
- ✅ Fecha de nacimiento, ocupación y referencia personal
- ✅ Aprobación manual del administrador antes de poder pujar
- ✅ Motivo del rechazo visible para el usuario
- ❌ **Pagaré o carta de compromiso firmada** (lo que usan todas las colombianas)
- ❌ Verificación de que el teléfono es real (código por SMS o WhatsApp)

### Respaldo económico
- ✅ Depósito de garantía por transferencia, con comprobante y confirmación manual
- ✅ El depósito se abona a la compra o se devuelve
- ❌ **Cupo máximo de compra por comprador** según su historial
- ❌ Depósito proporcional al valor de los lotes que quiere pujar

### Durante el remate
- ✅ Pujas en tiempo real, visibles para todos al instante
- ✅ Video en vivo incrustado
- ✅ Pujas del ruedo físico y en línea en una sola secuencia
- ✅ Incremento mínimo por lote
- ✅ Reglamento publicado y aceptado al registrarse
- ❌ Aviso al comprador cuando alguien lo supera en la puja
- ❌ Extensión automática del cierre si entra una puja en los últimos segundos

### Después de la venta
- ✅ Factura generada automáticamente
- ✅ Seguimiento del pago paso a paso, visible para el comprador
- ✅ Subida del comprobante de transferencia desde su cuenta
- ❌ CAI del SAR — sin eso la factura no tiene validez fiscal en Honduras
- ❌ Plazo de pago explícito con consecuencia automática al vencerse

---

## 4. Acceso del ADMINISTRADOR: lo que debe tener

### Seguridad de su propio acceso
- ✅ Cuenta con correo y contraseña, separada de las de compradores
- ✅ Permiso de administrador verificado en la base de datos, no en la pantalla
- ✅ Verificación en dos pasos disponible — **actívela, es su cuenta más valiosa**
- ✅ Recuperación de contraseña
- ❌ Una segunda cuenta de administrador de respaldo, por si pierde la suya
- ❌ Registro de quién hizo cada cambio y cuándo (bitácora de auditoría)

### Control de compradores
- ✅ Cola de verificación con todos los datos y las fotos de identidad
- ✅ Aprobar / rechazar con motivo
- ✅ Bloquear una cuenta en cualquier momento
- ✅ Cola de depósitos con el comprobante a la vista
- ✅ Directorio completo con teléfono, correo y WhatsApp directo
- ✅ **Marca de DUPLICADO** cuando dos cuentas comparten teléfono o identidad
- ❌ Historial de comportamiento por comprador (cuántas veces pagó tarde)

### Control del remate
- ✅ Crear la subasta, cargar lotes en orden, poner uno en vivo a la vez
- ✅ Panel del rematador aparte para registrar pujas del ruedo
- ✅ Cerrar como vendido o sin venta
- ✅ Anular no está disponible — ❌ falta poder anular una puja mal registrada

### Dinero
- ✅ Cinco estados de la venta hasta la liquidación al consignatario
- ✅ Cálculo automático de lo que le toca a cada vendedor
- ✅ Informe mensual y exportación a CSV
- ❌ Reporte de cuánto debe cada comprador en total, en un solo lugar
- ❌ Alerta de pagos vencidos

---

## 5. Lo que le falta, en orden de importancia

**Urgente — protege su dinero:**

1. **Carta de compromiso o pagaré firmado** antes de la primera puja. Es el
   candado que usan todas las subastas colombianas y el que a usted le falta.
   Puede empezar simple: un PDF que el comprador imprime, firma, fotografía y
   sube junto con su identidad. Yo se lo puedo agregar al flujo de verificación.
2. **Cupo máximo de compra por comprador.** Que la página no le deje pujar por
   encima de cierto monto hasta que usted se lo amplíe a mano. Hoy alguien con
   L10,000 de depósito puede adjudicarse L800,000.
3. **Plazo de pago con consecuencia.** Defina 48 horas (el estándar colombiano) y
   que la página marque sola las ventas vencidas.
4. **CAI del SAR.** Sin eso sus facturas no son válidas fiscalmente.

**Importante — hace que la subasta funcione mejor:**

5. **Aviso de "lo superaron"** por correo o WhatsApp. Es lo que mantiene viva la puja.
6. **Extensión automática del cierre**, para que nadie gane tirando la puja en el
   último segundo.
7. **Verificación del teléfono por SMS o WhatsApp** al registrarse.
8. **Segunda cuenta de administrador** de respaldo.

**Deseable:**

9. Bitácora de auditoría de cambios.
10. Historial de cumplimiento por comprador.
11. Cierre de sesión por inactividad.

---

## 6. Dos cosas específicas de Honduras

- **No copie el modelo de custodia de Koprix.** Retener el dinero del comprador
  hasta la entrega implica manejar fondos de terceros, y eso en Honduras lo
  acerca a figuras reguladas. Lo que usted hace hoy — el dinero llega directo a
  su cuenta como casa de subastas, y usted liquida al consignatario — es la
  figura tradicional y es la correcta.
- **No existe una "Asosubastas" hondureña donde reportar incumplidos**, ni acceso
  fácil a centrales de riesgo como Datacrédito. Eso le quita dos de los cinco
  candados que usan las colombianas. Por eso, en su caso, el **pagaré firmado y
  el cupo por comprador pesan el doble** — son los únicos dos que sí puede
  implementar solo.

---

*Documento preparado como insumo de trabajo. Las cifras de comisiones y plazos de
otras subastas son referenciales; verifíquelas en los reglamentos originales antes
de usarlas como base de los suyos.*
