# Notas de Diseño para Compilador CGRA (OpenEdge)

Este documento recopila reglas estrictas, restricciones de hardware y comportamientos no obvios descubiertos durante la verificación RTL. Estas reglas **deben** ser respetadas por cualquier compilador o generador de código para el HEEPsilon CGRA.

## 1. Restricciones de Inmediatos

### 1.1 Campo Inmediato Único (13 bits)
El hardware tiene **un solo campo inmediato (IMM)** de 13 bits por instrucción.
*   **Regla:** Una instrucción **NO** puede tener dos operandos inmediatos.
*   **Incorrecto:** `SADD R0, 10, 20` (Requiere dos campos IMM).
*   **Solución:** Cargar uno de los inmediatos en un registro en una instrucción previa.

### 1.2 Inmediatos en Saltos Condicionales (`BNE`, `BEQ`, `BLT`, `BGE`)
Las instrucciones de salto usan el campo `IMM` para almacenar la **dirección de destino** del salto.
*   **Regla:** Los operandos de comparación (`srcA`, `srcB`) **NO** pueden ser inmediatos.
*   **Incorrecto:** `BNE R0, -1, etiqueta` (El campo IMM se usa para `etiqueta`, no hay sitio para `-1`).
*   **Correcto:**
    1. Cargar `-1` en un registro (ej: `R1`) o recibirlo de un vecino.
    2. `BNE R0, R1, etiqueta`

### 1.3 Rango de Inmediatos
*   **Regla:** El campo es de 13 bits con signo.
*   **Rango:** [-4096, 4095].
*   Valores fuera de este rango deben construirse en varios ciclos o cargarse de memoria.

## 2. Latencia y Memoria

### 2.1 Latencia de Operaciones de Carga (`LWD`)
La instrucción `LWD` tiene un comportamiento específico en el pipeline:
1.  **Ciclo T (Ejecución LWD):**
    *   La ALU calcula el incremento del puntero.
    *   La dirección antigua se envía a memoria.
    *   **ROUT expone el valor del puntero**, NO el dato cargado.
2.  **Ciclo T+1:**
    *   El dato llega desde memoria y se escribe en el **Registro Destino** (`R0`-`R3`).
    *   El dato **NO** va automáticamente a `ROUT`.

*   **Regla:** El dato cargado por `LWD` está disponible para su uso (o para exponerlo a vecinos) en el ciclo **T+1**, y solo desde el registro destino.
*   **Patrón de Carga y Envío:**
    ```asm
    LWD R0              ; T: Solicita carga a R0
    SADD ROUT, R0, ZERO ; T+1: Expone R0 a ROUT (para vecinos)
    ```

### 2.2 Latencia de Multiplicación
*   **Regla:** Las instrucciones `SMUL` y `FXPMUL` pueden generar stalls automáticos si el hardware multiplica en varios ciclos. El compilador no necesita insertar NOPs explícitos para esperar el resultado *dentro* del mismo PE, el hardware se detiene.

## 3. Comunicación Inter-PE

### 3.1 Latencia de Vecinos (RCL, RCR, RCT, RCB)
*   **Regla:** La comunicación tiene **1 ciclo de latencia**.
*   Si PE(0,0) escribe en `ROUT` en el ciclo `T`, PE(0,1) puede leer ese valor usando `RCL` en el ciclo `T+1`.

### 3.2 Registro de Salida (ROUT) vs Registros Internos
*   `ROUT` es la salida directa de la ALU/Mux de salida. Su valor se actualiza en **cada ciclo** (excepto NOP).
*   `R0`-`R3` son registros de almacenamiento persistente.
*   **Regla:** Si un dato debe persistir más de un ciclo para ser leído por un vecino más tarde, debe guardarse en `R0`-`R3` y luego volver a exponerse a `ROUT` en el ciclo deseado.

## 4. Slots de Instrucciones (VLIW / Filas)
El contexto de ejecución se organiza en bloques de `N_ROWS` instrucciones que se ejecutan "simultáneamente" (en paralelo espacial, aunque serializadas temporalmente por acceso a memoria si hay conflictos).
*   **Conflicto de Memoria:** Si múltiples filas de la misma columna intentan acceder a memoria (LWD/SWD) en el mismo ciclo lógico, el hardware arbitra (generalmente round-robin o prioridad fija). Esto puede introducir stalls no deterministas.
*   **Recomendación:** Diseñar kernels donde solo una fila por columna acceda a memoria por ciclo para comportamiento determinista garantizado.
