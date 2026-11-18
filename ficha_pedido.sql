-- =====================================================================
--  TPI Base de Datos I – Sistema de gestión de pedidos de impresión
--  Etapa 4: Diseño físico e implementación en MySQL
--
--  Script completo: crea la base de datos desde cero.
--  Orden: 1) base de datos  2) tablas  3) datos de prueba
--  Requiere MySQL 8.0.16 o superior.
--
--  Nota: en los nombres se reemplazó la "ñ" por "n" (tamaño -> tamano)
--  para evitar problemas de codificación.
-- =====================================================================


-- =====================================================================
-- 1. CREACIÓN DE LA BASE DE DATOS
-- =====================================================================

DROP DATABASE IF EXISTS ficha_pedido;
CREATE DATABASE ficha_pedido
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_spanish_ci;
USE ficha_pedido;


-- =====================================================================
-- 2. CREACIÓN DE TABLAS
--    Primero las tablas que no dependen de otras (catálogos y personas),
--    después las que tienen claves foráneas.
-- =====================================================================

-- ---------------------------------------------------------------------
-- TAMANO: medidas que ofrece el negocio
-- ---------------------------------------------------------------------
CREATE TABLE tamano (
    id_tamano  INT          NOT NULL AUTO_INCREMENT,
    medidas    VARCHAR(20)  NOT NULL,
    ancho_cm   INT          NOT NULL,
    alto_cm    INT          NOT NULL,
    PRIMARY KEY (id_tamano),
    UNIQUE (medidas)
);

-- ---------------------------------------------------------------------
-- MATERIAL: soportes de impresión
-- ---------------------------------------------------------------------
CREATE TABLE material (
    id_material  INT          NOT NULL AUTO_INCREMENT,
    nombre       VARCHAR(50)  NOT NULL,
    PRIMARY KEY (id_material),
    UNIQUE (nombre)
);

-- ---------------------------------------------------------------------
-- OPCION: acabados y agregados
-- ---------------------------------------------------------------------
CREATE TABLE opcion (
    id_opcion    INT           NOT NULL AUTO_INCREMENT,
    nombre       VARCHAR(50)   NOT NULL,
    descripcion  VARCHAR(255),
    PRIMARY KEY (id_opcion),
    UNIQUE (nombre)
);

-- ---------------------------------------------------------------------
-- ETAPA: pasos del trabajo, con su orden
-- ---------------------------------------------------------------------
CREATE TABLE etapa (
    id_etapa  INT          NOT NULL AUTO_INCREMENT,
    nombre    VARCHAR(50)  NOT NULL,
    orden     INT          NOT NULL,
    PRIMARY KEY (id_etapa),
    UNIQUE (nombre),
    UNIQUE (orden)
);

-- ---------------------------------------------------------------------
-- CLIENTE: persona que encarga el trabajo
-- ---------------------------------------------------------------------
CREATE TABLE cliente (
    id_cliente      INT          NOT NULL AUTO_INCREMENT,
    nombre          VARCHAR(60)  NOT NULL,
    apellido        VARCHAR(60),
    telefono        VARCHAR(30),
    localidad       VARCHAR(80),
    zona            VARCHAR(80),
    es_profesional  BOOLEAN      NOT NULL DEFAULT FALSE,
    PRIMARY KEY (id_cliente)
);

-- ---------------------------------------------------------------------
-- EMPLEADO: quien descarga, imprime, factura o despacha
-- ---------------------------------------------------------------------
CREATE TABLE empleado (
    id_empleado  INT          NOT NULL AUTO_INCREMENT,
    nombre       VARCHAR(60)  NOT NULL,
    apellido     VARCHAR(60),
    PRIMARY KEY (id_empleado)
);

-- ---------------------------------------------------------------------
-- PEDIDO: cada ficha
-- AUTO_INCREMENT: el número de pedido es correlativo (regla 1)
-- CHECK: la fecha de salida no es anterior a la de entrada (restricción 4)
-- ---------------------------------------------------------------------
CREATE TABLE pedido (
    nro_pedido     INT            NOT NULL AUTO_INCREMENT,
    id_cliente     INT            NOT NULL,
    fecha_entrada  DATE           NOT NULL,
    fecha_ingreso  DATE,
    fecha_salida   DATE,
    monto_total    DECIMAL(10,2)  NOT NULL,
    PRIMARY KEY (nro_pedido),
    FOREIGN KEY (id_cliente) REFERENCES cliente (id_cliente)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CHECK (fecha_salida >= fecha_entrada),
    CHECK (monto_total >= 0)
);

-- ---------------------------------------------------------------------
-- ITEM_PEDIDO: cada línea del pedido (tamaño + material + cantidad)
-- DEFAULT 1: si no se indica material, se usa "Papel fotográfico común"
--            (supuesto 10)
-- CHECK: la cantidad es mayor que cero (restricción 3)
-- ---------------------------------------------------------------------
CREATE TABLE item_pedido (
    id_item      INT  NOT NULL AUTO_INCREMENT,
    nro_pedido   INT  NOT NULL,
    id_tamano    INT  NOT NULL,
    id_material  INT  NOT NULL DEFAULT 1,
    cantidad     INT  NOT NULL,
    PRIMARY KEY (id_item),
    FOREIGN KEY (nro_pedido) REFERENCES pedido (nro_pedido)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (id_tamano) REFERENCES tamano (id_tamano)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (id_material) REFERENCES material (id_material)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CHECK (cantidad > 0)
);

-- ---------------------------------------------------------------------
-- ITEM_OPCION: resuelve la relación N:M entre ÍTEM y OPCIÓN
-- UNIQUE: la misma opción no se repite en un ítem (restricción 7)
-- ---------------------------------------------------------------------
CREATE TABLE item_opcion (
    id_item_opcion  INT  NOT NULL AUTO_INCREMENT,
    id_item         INT  NOT NULL,
    id_opcion       INT  NOT NULL,
    PRIMARY KEY (id_item_opcion),
    UNIQUE (id_item, id_opcion),
    FOREIGN KEY (id_item) REFERENCES item_pedido (id_item)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (id_opcion) REFERENCES opcion (id_opcion)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------
-- REGISTRO_ETAPA: qué empleado completó qué etapa de un pedido y cuándo
-- UNIQUE: cada etapa se registra una sola vez por pedido (restricción 6)
-- ---------------------------------------------------------------------
CREATE TABLE registro_etapa (
    id_registro  INT       NOT NULL AUTO_INCREMENT,
    nro_pedido   INT       NOT NULL,
    id_etapa     INT       NOT NULL,
    id_empleado  INT       NOT NULL,
    fecha_hora   DATETIME  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_registro),
    UNIQUE (nro_pedido, id_etapa),
    FOREIGN KEY (nro_pedido) REFERENCES pedido (nro_pedido)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (id_etapa) REFERENCES etapa (id_etapa)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (id_empleado) REFERENCES empleado (id_empleado)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------
-- PAGO: cada cobro de un pedido (permite seña y saldo)
-- CHECK: el monto de un pago es mayor que cero
-- ---------------------------------------------------------------------
CREATE TABLE pago (
    id_pago     INT            NOT NULL AUTO_INCREMENT,
    nro_pedido  INT            NOT NULL,
    fecha       DATE           NOT NULL,
    monto       DECIMAL(10,2)  NOT NULL,
    forma_pago  VARCHAR(30),
    PRIMARY KEY (id_pago),
    FOREIGN KEY (nro_pedido) REFERENCES pedido (nro_pedido)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CHECK (monto > 0)
);

-- Reglas que NO se implementan en el script y quedan a cargo del sistema
-- (ver Etapa 2, punto 6):
--   - La suma de los pagos no supera el monto total del pedido.
--   - Un pedido no se despacha si no está pagado.
--   - Las etapas se registran en orden.
--   - Mate y Brillo son excluyentes en un ítem.
--   - "Con bastidor" solo para canvas o lona.
--   - "Sólo impresión" no lleva bastidor ni imán.


-- =====================================================================
-- 3. DATOS DE PRUEBA
-- =====================================================================

-- ---------------------------------------------------------------------
-- 3.1 Catálogos (tomados de la ficha)
-- ---------------------------------------------------------------------
INSERT INTO tamano (medidas, ancho_cm, alto_cm) VALUES
    ('9x13',   9, 13),    -- 1
    ('10x15', 10, 15),    -- 2
    ('13x18', 13, 18),    -- 3
    ('15x21', 15, 21),    -- 4
    ('20x30', 20, 30),    -- 5
    ('30x40', 30, 40),    -- 6
    ('30x45', 30, 45),    -- 7
    ('30x60', 30, 60);    -- 8

INSERT INTO material (nombre) VALUES
    ('Papel fotográfico común'),   -- 1 (por defecto)
    ('Papel mate'),                -- 2
    ('Papel brillo'),              -- 3
    ('Lona front'),                -- 4
    ('Lona blackout'),             -- 5
    ('Canvas'),                    -- 6
    ('Ecocuero'),                  -- 7
    ('Otros');                     -- 8

INSERT INTO opcion (nombre, descripcion) VALUES
    ('Brillo',         'Acabado brillante'),                                -- 1
    ('Mate',           'Acabado mate'),                                     -- 2
    ('Con margen',     'La imagen se imprime con borde blanco'),            -- 3
    ('Llenar formato', 'La imagen se recorta para ocupar todo el tamaño'),  -- 4
    ('Adaptar imagen', 'La imagen se ajusta al tamaño sin recortar'),       -- 5
    ('Imán',           'Se monta sobre base imantada'),                     -- 6
    ('Con bastidor',   'Se monta sobre bastidor'),                          -- 7
    ('Sólo impresión', 'Sin terminación ni agregados');                     -- 8

INSERT INTO etapa (nombre, orden) VALUES
    ('Descarga',    1),
    ('Impresión',   2),
    ('Facturación', 3),
    ('Despacho',    4);

-- ---------------------------------------------------------------------
-- 3.2 Clientes y empleados
-- ---------------------------------------------------------------------
INSERT INTO cliente (nombre, apellido, telefono, localidad, zona, es_profesional) VALUES
    ('Ivana',  NULL,        NULL,           NULL,       NULL,     FALSE),  -- 1 (ficha original)
    ('Martín', 'Gómez',     '11-5555-1234', 'Quilmes',  'Sur',    TRUE),   -- 2 profesional
    ('Lucía',  'Fernández', '11-4444-9876', 'Bernal',   'Sur',    FALSE),  -- 3
    ('Carlos', 'Ramírez',   '11-3333-5678', 'Avellaneda','Centro', TRUE);  -- 4 profesional

INSERT INTO empleado (nombre, apellido) VALUES
    ('Laura', 'Pérez'),    -- 1
    ('Diego', 'Ruiz'),     -- 2
    ('Sofía', 'Medina');   -- 3

-- ---------------------------------------------------------------------
-- 3.3 Pedidos: cada uno muestra una situación distinta del negocio
-- ---------------------------------------------------------------------

-- Pedido 43646: la ficha original de Ivana.
-- Pagado, sin etapas registradas. Monto ilustrativo (la ficha no lo tiene).
INSERT INTO pedido (nro_pedido, id_cliente, fecha_entrada, fecha_ingreso, fecha_salida, monto_total)
VALUES (43646, 1, '2026-08-26', NULL, NULL, 15000.00);

-- Pedido 43647: cliente profesional, dos ítems, con seña, en facturación.
INSERT INTO pedido (id_cliente, fecha_entrada, fecha_ingreso, fecha_salida, monto_total)
VALUES (2, '2026-11-02', '2026-11-03', NULL, 40000.00);

-- Pedido 43648: recién recibido, sin pago y sin etapas.
INSERT INTO pedido (id_cliente, fecha_entrada, fecha_ingreso, fecha_salida, monto_total)
VALUES (3, '2026-11-14', NULL, NULL, 8000.00);

-- Pedido 43649: profesional, pagado en dos partes, terminado y despachado.
INSERT INTO pedido (id_cliente, fecha_entrada, fecha_ingreso, fecha_salida, monto_total)
VALUES (4, '2026-10-20', '2026-10-21', '2026-10-25', 60000.00);

-- Pedido 43650: cliente que repite (Ivana), pagado, ya impreso.
INSERT INTO pedido (id_cliente, fecha_entrada, fecha_ingreso, fecha_salida, monto_total)
VALUES (1, '2026-11-05', '2026-11-06', NULL, 22000.00);

-- Pedido 43651: con seña, recién descargado.
INSERT INTO pedido (id_cliente, fecha_entrada, fecha_ingreso, fecha_salida, monto_total)
VALUES (3, '2026-11-12', '2026-11-13', NULL, 18000.00);

-- ---------------------------------------------------------------------
-- 3.4 Ítems de cada pedido
-- ---------------------------------------------------------------------

-- Ítem 1 (pedido 43646): 10x15, 10 copias, SIN material indicado
-- -> toma el material por defecto (Papel fotográfico común)
INSERT INTO item_pedido (nro_pedido, id_tamano, cantidad)
VALUES (43646, 2, 10);

INSERT INTO item_pedido (nro_pedido, id_tamano, id_material, cantidad) VALUES
    (43647, 6, 6, 1),     -- 2: 30x40 en canvas, 1 copia
    (43647, 3, 2, 20),    -- 3: 13x18 en papel mate, 20 copias
    (43648, 5, 3, 5),     -- 4: 20x30 en papel brillo, 5 copias
    (43649, 8, 4, 2),     -- 5: 30x60 en lona front, 2 copias
    (43650, 1, 3, 30),    -- 6: 9x13 en papel brillo, 30 copias
    (43650, 4, 1, 4),     -- 7: 15x21 en papel común, 4 copias
    (43651, 7, 7, 1);     -- 8: 30x45 en ecocuero, 1 copia

-- ---------------------------------------------------------------------
-- 3.5 Opciones de cada ítem (relación N:M)
-- ---------------------------------------------------------------------
INSERT INTO item_opcion (id_item, id_opcion) VALUES
    (2, 7),    -- canvas con bastidor
    (3, 2),    -- papel mate: acabado mate
    (3, 3),    --             con margen
    (4, 1),    -- papel brillo: acabado brillo
    (5, 8),    -- lona: sólo impresión
    (6, 1),    -- 9x13: brillo
    (6, 5),    --       adaptar imagen
    (7, 6),    -- 15x21: imán
    (8, 4);    -- ecocuero: llenar formato
-- El ítem 1 (pedido de Ivana) no lleva opciones, como en la ficha.

-- ---------------------------------------------------------------------
-- 3.6 Pagos
-- ---------------------------------------------------------------------
INSERT INTO pago (nro_pedido, fecha, monto, forma_pago) VALUES
    (43646, '2026-08-26', 15000.00, NULL),             -- pago total, forma desconocida
    (43647, '2026-11-02', 15000.00, 'Transferencia'),  -- seña (debe 25000)
    (43649, '2026-10-20', 30000.00, 'Efectivo'),       -- seña
    (43649, '2026-10-25', 30000.00, 'Transferencia'),  -- saldo -> pagado
    (43650, '2026-11-05', 22000.00, 'Débito'),         -- pago total
    (43651, '2026-11-12',  5000.00, 'Efectivo');       -- seña (debe 13000)
-- El pedido 43648 no tiene pagos.

-- ---------------------------------------------------------------------
-- 3.7 Registro de etapas (control interno)
-- ---------------------------------------------------------------------
INSERT INTO registro_etapa (nro_pedido, id_etapa, id_empleado, fecha_hora) VALUES
    -- 43647: descargado, impreso y facturado
    (43647, 1, 1, '2026-11-03 09:30:00'),
    (43647, 2, 2, '2026-11-04 11:00:00'),
    (43647, 3, 3, '2026-11-05 10:15:00'),
    -- 43649: todas las etapas, despachado
    (43649, 1, 1, '2026-10-21 09:00:00'),
    (43649, 2, 2, '2026-10-22 15:30:00'),
    (43649, 3, 3, '2026-10-23 10:00:00'),
    (43649, 4, 2, '2026-10-25 12:00:00'),
    -- 43650: descargado e impreso
    (43650, 1, 1, '2026-11-06 10:00:00'),
    (43650, 2, 2, '2026-11-07 16:00:00'),
    -- 43651: solo descargado
    (43651, 1, 3, '2026-11-13 09:45:00');
-- Los pedidos 43646 y 43648 no tienen etapas registradas.
