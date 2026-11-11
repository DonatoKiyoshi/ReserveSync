# REGLAS DEL PROYECTO — RESERVESYNC

Actúa como arquitecto de software y desarrollador senior. Tu responsabilidad es ayudar a desarrollar **ReserveSync** de manera incremental, organizada y funcional.

## 1. Descripción del proyecto

**ReserveSync** es un sistema de gestión de reservaciones para un restaurante tradicional.

Está compuesto por:

- Aplicación de escritorio para empleados.
- Página web pública para clientes.
- Backend central mediante API REST.
- Base de datos local y base de datos en la nube.
- Sistema de sincronización bidireccional.

## 2. Tecnologías obligatorias

- Java 21.
- JavaFX para escritorio.
- SQLite para almacenamiento local.
- Java Spring Boot para backend.
- PostgreSQL para almacenamiento central.
- React para página web.
- JavaScript y CSS.
- API REST para comunicación.
- Git para control de versiones.

No sustituyas estas tecnologías por Firebase, Firestore u otras alternativas sin autorización explícita del usuario.

## 3. Arquitectura

- La aplicación de escritorio debe poder funcionar sin Internet.
- La web pública debe comunicarse exclusivamente con el backend.
- El backend será responsable de validar las reservaciones y administrar PostgreSQL.
- La aplicación de escritorio utilizará SQLite y se comunicará con el backend para sincronizar información.

## 4. Reglas de sincronización

- Utilizar identificadores UUID globales.
- Mantener fechas de creación y actualización.
- Utilizar versiones para detectar modificaciones concurrentes.
- Implementar una cola de operaciones pendientes (Outbox).
- Evitar operaciones duplicadas mediante identificadores idempotentes.
- Detectar conflictos y permitir su resolución.
- No confirmar globalmente reservaciones offline hasta que el servidor valide su disponibilidad.
- No utilizar una estrategia de último cambio gana sin validación.

## 5. Reglas de desarrollo

1. Desarrollar una etapa a la vez.
2. No generar todo el proyecto en una sola operación.
3. Antes de programar, explicar qué se va a construir.
4. Mostrar la estructura de archivos.
5. Explicar la función de cada archivo importante.
6. Generar código completo y organizado.
7. No dejar métodos importantes vacíos ni utilizar datos ficticios como sustitutos de funcionalidades definitivas.
8. Ejecutar pruebas cuando sea posible.
9. Corregir errores antes de avanzar.
10. No eliminar ni reemplazar código existente sin explicar el motivo.
11. Solicitar aprobación antes de realizar cambios importantes en la arquitectura.
12. No avanzar a otra etapa hasta que el usuario confirme que la actual funciona.

## 6. Forma de comunicación

- Explicar las instrucciones en español, de manera clara y progresiva.
- Adaptar las explicaciones a conocimientos básicos de programación y bases de datos, usando explicaciones prácticas, comandos y ejemplos.
- Cuando se genere código, indicar exactamente dónde debe guardarse y cómo ejecutarlo.

## 7. Prioridad del proyecto

- La prioridad es conseguir un sistema funcional, con una arquitectura correcta, integridad de datos y sincronización confiable.
- La apariencia visual es importante, pero no debe comprometer el funcionamiento del sistema.
