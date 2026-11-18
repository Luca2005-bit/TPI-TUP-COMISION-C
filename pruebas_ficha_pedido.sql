-- =====================================================================
--  PRUEBAS – Base de datos ficha_pedido
--  Ejecutar DESPUÉS de ficha_pedido.sql
--  En Workbench: seleccioná una consulta con el mouse y tocá el rayo.
-- =====================================================================

USE ficha_pedido;


-- =====================================================================
-- PARTE 1: CONSULTAS (tienen que funcionar)
-- =====================================================================

-- 1. Todos los pedidos con su cliente
SELECT p.nro_pedido, c.nombre, c.apellido, p.fecha_entrada, p.monto_total
FROM pedido p
JOIN cliente c ON c.id_cliente = p.id_cliente
ORDER BY p.nro_pedido;

-- 2. Detalle de cada pedido: tamaño, material y cantidad
--    (el ítem de Ivana tiene que mostrar "Papel fotográfico común")
SELECT i.nro_pedido, t.medidas, m.nombre AS material, i.cantidad
FROM item_pedido i
JOIN tamano t   ON t.id_tamano   = i.id_tamano
JOIN material m ON m.id_material = i.id_material
ORDER BY i.nro_pedido;

-- 3. Opciones elegidas en cada ítem
SELECT i.nro_pedido, i.id_item, o.nombre AS opcion
FROM item_opcion io
JOIN item_pedido i ON i.id_item   = io.id_item
JOIN opcion o      ON o.id_opcion = io.id_opcion
ORDER BY i.nro_pedido, i.id_item;

-- 4. Cuánto pagó cada pedido y cuánto debe
--    Esperado: 43646, 43649 y 43650 sin deuda; 43647 debe 25000;
--              43648 debe 8000; 43651 debe 13000
SELECT p.nro_pedido, p.monto_total,
       COALESCE(SUM(pg.monto), 0)                 AS pagado,
       p.monto_total - COALESCE(SUM(pg.monto), 0) AS saldo
FROM pedido p
LEFT JOIN pago pg ON pg.nro_pedido = p.nro_pedido
GROUP BY p.nro_pedido, p.monto_total
ORDER BY p.nro_pedido;

-- 5. Pedidos que todavía tienen deuda
SELECT p.nro_pedido, p.monto_total, COALESCE(SUM(pg.monto), 0) AS pagado
FROM pedido p
LEFT JOIN pago pg ON pg.nro_pedido = p.nro_pedido
GROUP BY p.nro_pedido, p.monto_total
HAVING pagado < p.monto_total;

-- 6. Historial de un pedido: quién hizo cada etapa y cuándo
SELECT e.orden, e.nombre AS etapa, em.nombre AS empleado, r.fecha_hora
FROM registro_etapa r
JOIN etapa e     ON e.id_etapa     = r.id_etapa
JOIN empleado em ON em.id_empleado = r.id_empleado
WHERE r.nro_pedido = 43649
ORDER BY e.orden;

-- 7. Pedidos de clientes profesionales
SELECT p.nro_pedido, c.nombre, c.apellido
FROM pedido p
JOIN cliente c ON c.id_cliente = p.id_cliente
WHERE c.es_profesional = TRUE;

-- 8. Cantidad de pedidos por cliente
SELECT c.nombre, c.apellido, COUNT(p.nro_pedido) AS cantidad_pedidos
FROM cliente c
LEFT JOIN pedido p ON p.id_cliente = c.id_cliente
GROUP BY c.id_cliente, c.nombre, c.apellido;


-- =====================================================================
-- PARTE 2: RESTRICCIONES (cada una TIENE QUE DAR ERROR)
-- Ejecutalas de a una. Si da error, la restricción funciona.
-- =====================================================================

-- E1. Cantidad 0 -> CHECK (cantidad > 0)
INSERT INTO item_pedido (nro_pedido, id_tamano, id_material, cantidad)
VALUES (43648, 1, 2, 0);

-- E2. Fecha de salida anterior a la de entrada -> CHECK de fechas
INSERT INTO pedido (id_cliente, fecha_entrada, fecha_salida, monto_total)
VALUES (1, '2026-11-16', '2026-11-10', 1000.00);

-- E3. Cliente que no existe -> FOREIGN KEY
INSERT INTO pedido (id_cliente, fecha_entrada, monto_total)
VALUES (999, '2026-11-16', 1000.00);

-- E4. Tamaño que no existe -> FOREIGN KEY
INSERT INTO item_pedido (nro_pedido, id_tamano, id_material, cantidad)
VALUES (43648, 99, 2, 5);

-- E5. Registrar la misma etapa dos veces en un pedido -> UNIQUE
INSERT INTO registro_etapa (nro_pedido, id_etapa, id_empleado)
VALUES (43649, 1, 2);

-- E6. Repetir una opción en el mismo ítem -> UNIQUE
INSERT INTO item_opcion (id_item, id_opcion) VALUES (3, 2);

-- E7. Tamaño repetido en el catálogo -> UNIQUE
INSERT INTO tamano (medidas, ancho_cm, alto_cm) VALUES ('10x15', 10, 15);

-- E8. Pedido sin fecha de entrada -> NOT NULL
INSERT INTO pedido (id_cliente, fecha_entrada, monto_total)
VALUES (1, NULL, 1000.00);

-- E9. Borrar un cliente que tiene pedidos -> ON DELETE RESTRICT
DELETE FROM cliente WHERE id_cliente = 1;

-- E10. Pago con monto negativo -> CHECK (monto > 0)
INSERT INTO pago (nro_pedido, fecha, monto) VALUES (43648, '2026-11-16', -500.00);


-- =====================================================================
-- PARTE 3: VALORES POR DEFECTO (tiene que funcionar)
-- =====================================================================

-- Pedido nuevo sin número: toma el siguiente (43652).
-- Ítem sin material: toma "Papel fotográfico común".
-- Cliente sin indicar si es profesional: queda en FALSE.
INSERT INTO cliente (nombre) VALUES ('Prueba');
INSERT INTO pedido (id_cliente, fecha_entrada, monto_total) VALUES (5, '2026-11-16', 3000.00);
INSERT INTO item_pedido (nro_pedido, id_tamano, cantidad) VALUES (43652, 2, 15);

SELECT p.nro_pedido, c.nombre, c.es_profesional, m.nombre AS material
FROM pedido p
JOIN cliente c     ON c.id_cliente  = p.id_cliente
JOIN item_pedido i ON i.nro_pedido  = p.nro_pedido
JOIN material m    ON m.id_material = i.id_material
WHERE p.nro_pedido = 43652;
