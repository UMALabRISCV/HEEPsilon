1. # Setup

El setup es idéntico al de x-heep, aunque parece que el venv da más problemas que conda.

Siguiendo la guía:

| [https://github.com/esl-epfl/HEEPsilon/tree/main/hw/vendor/esl\_epfl\_x\_heep](https://github.com/esl-epfl/HEEPsilon/tree/main/hw/vendor/esl_epfl_x_heep) |
| :---- |

Construimos y cargamos el entorno virtual:

| make condaconda activate core-v-mini-mcu |
| :---- |

Compilamos el microcontrolador:

| make mcu-gen CPU=cv32e20 BUS=NtoM MEMORY\_BANKS=8 MEMORY\_BANKS\_IL=8 |
| :---- |

Compilamos el software:

| make clean-app ; make app PROJECT=cgra\_fft TARGET=sim |
| :---- |

Compilamos la simulación, la ejecutamos y msotramos los resultados:

| make verilator-sim && cd ./build/eslepfl\_systems\_cgra-x-heep\_0/sim-verilator && ./Vtestharness \+firmware=../../../sw/build/main.hex && cat uart0.log && cd ../../.. |
| :---- |

2. # Aplicaciones de Ejemplo

   1. ## cgra\_fft

Este código implementa una transformada rápida de Fourier (FFT) radix-2 en la CGRA. Utiliza dos kernels principales: uno para realizar el reordenamiento de bits de las muestras de entrada y otro para calcular la FFT de números complejos a partir de las muestras reordenadas. La implementación permite ejecutar una sola FFT o dos al mismo tiempo para aprovechar al máximo la CGRA. Además, ofrece la opción de realizar una FFT infinita para medir el consumo energético. El código también incluye un kernel para realizar FFT de números reales, pero está actualmente obsoleto para la arquitectura CGRA actual. Se sugiere que se modifique el kernel para adaptarlo.

Se ha modificado el main para poder sacar los ciclos que tarda la CGRA en computar la FFT. Simplemente se le ha añadido:

| \#include "csr.h" |
| :---- |

|   ////////////////////////////////////////////////////////////////  // Performance regs variables  unsigned int cycles\_start \= 0, cycles\_end \= 0;  //////////////////////////////////////////////////////////////// |
| :---- |

|   ////////////////////////////////////////////////////////////////  // Starting the performance counter  CSR\_CLEAR\_BITS(CSR\_REG\_MCOUNTINHIBIT, 0x1);  CSR\_READ(CSR\_REG\_MCYCLE, \&cycles\_start);  //CSR\_WRITE(CSR\_REG\_MCYCLE, 0);  //////////////////////////////////////////////////////////////// |
| :---- |

|   ////////////////////////////////////////////////////////////////  // stop the HW counter used for monitoring  CSR\_READ(CSR\_REG\_MCYCLE, \&cycles\_end);  printf("Number of clock cycles: %d\\n", cycles\_end \- cycles\_start);  //////////////////////////////////////////////////////////////// |
| :---- |

Resultados:

2. ## cgra\_dbl\_search

Este código realiza búsquedas del valor mínimo y máximo en un conjunto de datos utilizando la CGRA. Implementa dos kernels para la CGRA: uno para encontrar el valor mínimo y otro para encontrar el valor máximo. Los resultados de las búsquedas se comparan con los valores esperados para verificar la corrección de la operación. Además, se muestran en pantalla los resultados obtenidos y se recopila información sobre los ciclos activos y de espera de cada columna de la CGRA, así como el número total de ejecuciones del kernel.

Resultados:

| Run double minimum search on CGRA...CGRA double minimum check finished with 0 errorsCGRA kernel executed: 1Run double maximum search on cpu...doneRun double maximum search on CGRA...CGRA double maximum check finished with 0 errorsCGRA kernel executed: 2CGRA column 0 active cycles: 1103CGRA column 0 stall cycles : 212CGRA column 1 active cycles: 0CGRA column 1 stall cycles : 0CGRA column 2 active cycles: 0CGRA column 2 stall cycles : 0CGRA column 3 active cycles: 0CGRA column 3 stall cycles : 0 |
| :---- |

3. ## cgra\_func\_test

Este programa es un conjunto de pruebas diseñadas para verificar el funcionamiento de una CGRA. Realiza una serie de operaciones en una matriz de datos de entrada y compara los resultados con valores esperados predefinidos. Las operaciones realizadas son: suma (SADD), resta (SSUB), multiplicación (SMUL), multiplicación con punto fijo (FXPMUL), desplazamiento a la derecha aritmético (SRA), comparación menor que (SLT), desplazamiento lógico a la derecha (SRT) y asignación de cero o menos que cero (BSFA y BZFA).

Resultado:

| Init CGRA context memory...doneRun functionality check on CGRA...CGRA functionality check finished with 0 errorsCGRA kernel executed: 1CGRA column 0 active cycles: 355CGRA column 0 stall cycles : 176CGRA column 1 active cycles: 355CGRA column 1 stall cycles : 176CGRA column 2 active cycles: 355CGRA column 2 stall cycles : 176CGRA column 3 active cycles: 355CGRA column 3 stall cycles : 176CGRA kernel executed (after counter reset): 0CGRA column 0 active cycles: 0CGRA column 0 stall cycles : 0CGRA column 1 active cycles: 0CGRA column 1 stall cycles : 0CGRA column 2 active cycles: 0CGRA column 2 stall cycles : 0CGRA column 3 active cycles: 0CGRA column 3 stall cycles : 0 |
| :---- |

4. ## kernel\_test

El programa ejecuta múltiples kernels en una estructura dada. Se carga una serie de kernels, se inicializan las variables de rendimiento y se realiza un bucle para cada kernel. En cada iteración, se carga el kernel en la CGRA, se configura, se ejecuta en software (opcional), y luego se ejecuta en la CGRA. Se registran y analizan los tiempos de carga, ejecución en software y ejecución en la CGRA. Finalmente, se generan estadísticas sobre el rendimiento y los errores para cada kernel.

A continuación la salida de todos los kernels de ejemplo. La segunda columna representa el promedio de tiempo (en ciclos de reloj) que tarda en ejecutarse el algoritmo. La tercera, indica la desviación estándar del tiempo de ejecución, medida en porcentaje.

| convolution\[0\] 66 \!= 0\[1\] 0 \!= 0\[2\] 0 \!= 0⋮\[25\] 0 \!= 106\[26\] 0 \!= 0\[0\] 66 \!= 0\[1\] 0 \!= 0⋮\[24\] 0 \!= 0\[25\] 0 \!= 106\[26\] 0 \!= 0SOFT    1175    0.0CONF    61      0.0REPO    147     0.0CGRA    98      0.0E       0 |
| :---- |

|  ReversebitsSOFT    338     0.0CONF    26      0.0REPO    119     0.0CGRA    110     0.0E       0 |
| :---- |

|  BitcountSOFT    110     22.20CONF    44      9.80REPO    63      9.80CGRA    55      9.80E       0 |
| :---- |

|  SqrtSOFT    181     3.40CONF    39      0.0REPO    138     0.0CGRA    128     0.0E       0 |
| :---- |

|  GsmSOFT    489     1.50CONF    84      0.0REPO    366     0.0CGRA    308     0.0E       0 |
| :---- |

|  StrsearchSOFT    1103    0.90CONF    84      0.0REPO    411     0.0CGRA    304     0.0E       0 |
| :---- |

|  ShaSOFT    1099    0.0CONF    76      0.0REPO    936     0.0CGRA    604     0.0E       0 |
| :---- |

|  Sha2SOFT    563     0.0CONF    47      0.0REPO    311     0.0CGRA    257     0.0E       0 |
| :---- |

|  StrsearchSOFT    1103    0.90CONF    84      0.0REPO    408     0.0CGRA    302     0.0E       0 |
| :---- |

3. # Generar un bitstream

Es posible generar el bitstream de la CGRA a partir del out.sat que se genera en la salida del compilador SAT-MapIt.

Deberemos crear una nueva carpeta con el nombre de nuestro kernel (en este caso "min") en la ruta sw/applications/kernel\_test/kernels. Dentro de esta carpeta deberemos crear otra que indique las dimensiones de la CGRA que vamos a utilizar (en este caso "4x4"), también agregaremos el out.sat a ésta última carpeta de las dimensiones y finalmente se agrega un archivo inouts que indica las entradas y salidas del kernel. deberemos tener una estructura como:

| . └── sw     └── applications         └── kernel\_test             └── kernels                 └── min                     ├── 4x4                     │   └── out.sat                     └── inouts  |
| :---- |

El contenido de inouts debe ser similar a:

| 31  in  array  1   var 41  in  len  1   var 53  out min 1   var |
| :---- |

Una vez añadidas las carpetas y ficheros necesarios, nos movemos a sw/applications/kernel\_test/utils. Desde aquí ejecutamos inst\_encoder.py pasándole como argumentos la ruta a la carpeta del kernel y las dimensiones de la CGRA.

| python3 inst\_encoder.py ../kernels/min 4x4 |
| :---- |

Una vez ejecutado debemos obtener varios ficheros nuevos:

| . └── sw     └── applications         └── kernel\_test             └── kernels                 └── min                     ├── 4x4                     │   ├── bitstreams                     │   ├── io.json                     │   ├── min.c                     │   ├── min.h                     │   └── out.sat                     └── inouts |
| :---- |

4. # Enlaces interesantes

* [https://github.com/esl-epfl/OpenEdgeCGRA](https://github.com/esl-epfl/OpenEdgeCGRA): Se explica la arquitectura de la CGRA y su funcionamiento.  
* [https://github.com/esl-epfl/OpenEdgeCGRA/blob/main/docs/OpenEdgeCGRA-ISA.pdf](https://github.com/esl-epfl/OpenEdgeCGRA/blob/main/docs/OpenEdgeCGRA-ISA.pdf): Especifíca el conjunto de instrucciones que puede ejecutar la CGRA.