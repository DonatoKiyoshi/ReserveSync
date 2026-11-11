# ReserveSync

Sistema de gestión de reservaciones para un restaurante tradicional, diseñado con operación local sin conexión (offline-first en escritorio) y sincronización bidireccional confiable con un servidor central.

## Objetivos

- Permitir a los clientes consultar disponibilidad y realizar reservaciones desde una página web pública.
- Permitir a los empleados gestionar reservaciones en el restaurante desde una aplicación de escritorio, incluso sin conexión a Internet.
- Garantizar la integridad de los datos y evitar reservas duplicadas o sobrecupo mediante validación centralizada en el servidor.
- Sincronizar cambios bidireccionalmente usando identificadores UUID globales, control de versiones, cola de operaciones pendientes (*Outbox*), idempotencia y detección/resolución de conflictos.

## Stack tecnológico

| Componente | Tecnología |
| --- | --- |
| Lenguaje principal (Backend y Escritorio) | Java 21 |
| Backend / API REST | Java Spring Boot |
| Aplicación de escritorio | JavaFX |
| Base de datos local (escritorio) | SQLite |
| Base de datos central | PostgreSQL |
| Página web pública | React (JavaScript y CSS) |
| Control de versiones | Git |

## Arquitectura general

- **Web pública (`web/`)**: se comunica exclusivamente con el backend mediante API REST.
- **Backend (`backend/`)**: valida reglas de negocio, disponibilidad de mesas/horarios, administra **PostgreSQL** y procesa la sincronización.
- **Escritorio (`desktop/`)**: opera contra **SQLite** de forma local (permitiendo trabajar sin Internet) y sincroniza las operaciones pendientes con el backend mediante una cola *Outbox* cuando hay conexión.

## Estructura del repositorio

```text
ReserveSync/
├── docs/
│   ├── arquitectura/       # Decisiones de arquitectura y protocolo de sincronización
│   ├── diagramas/          # Diagramas de flujo, secuencia y componentes
│   └── especificaciones/   # Requisitos funcionales, reglas de negocio y casos de uso
├── database/
│   ├── sqlite/             # Esquemas SQL y migraciones para la base local
│   ├── postgresql/         # Esquemas SQL y migraciones para la base central
│   ├── diagrams/           # Diagramas Entidad-Relación (ER) y diccionario de datos
│   └── seed/               # Datos iniciales (mesas, horarios, configuración base)
├── backend/                # API REST central en Java 21 + Spring Boot
├── desktop/                # Aplicación de escritorio en Java 21 + JavaFX
├── web/                    # Aplicación web pública en React (JS + CSS)
├── .gitignore              # Exclusiones de Git (Java, Maven, Node.js, IntelliJ, BD locales)
├── AGENTS.md               # Reglas de arquitectura, sincronización y desarrollo del proyecto
└── README.md               # Documentación general del proyecto
```

## Estado actual

- **Etapa 1**: Estructura inicial del proyecto, documentación base y configuración del repositorio.
