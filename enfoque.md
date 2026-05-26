**Trabajo  Final: Desarrollo de un Juego Multijugador en Paradigma Funcional**

**1\. Objetivo del Proyecto**  
Implementar un sistema de juego interactivo para mínimo 3 jugadores simultáneos, utilizando exclusivamente un lenguaje de programación funcional (Elixir, Clojure o Scala). 

**2\. Requisitos Técnicos Obligatorios**

* Se debe trabajar con estructura de datos inmutables (Mapas, Registros o Tuplas).  
* Se debe definirse mediante funciones puras   
* **Sincronización:** El servidor debe ser capaz de gestionar al menos 3 conexiones activas y mantener un estado coherente para todos.  
* **Concurrencia:** Se debe utilizar el modelo de Actores o Agentes (procesos ligeros) para manejar a cada jugador y el bucle principal del juego.  
* **Comunicación:** Implementar el intercambio de datos mediante el paso de mensajes (en tiempo real o por turnos rápidos).  
* Debe permitir visualizar la posición y acciones de los otros jugadores en tiempo real.  
* Se puede usar HTML/Canvas vía WebSockets o bibliotecas gráficas nativas del lenguaje elegido.

**3\. Entregables** (30/06)  
Código Fuente, con instrucciones claras de ejecución.  
Documentación Técnica:

* Diagrama de la estructura del Juego.  
  * Explicación de la estrategia de concurrencia utilizada.  
  * Definición de las principales funciones 

**Avance 1:** Definición del juego y lenguaje de programación, además de generar el borrador del diagrama de la estructura del juego. 20 LP \- 28/05  
**Avance 2:** Entrega del avance del juego al 50% y un manual del LP utilizado. 18/06  
