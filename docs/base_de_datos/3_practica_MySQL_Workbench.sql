-- =====================================================================
--  VERTEX AI Pyme · PRÁCTICA EN MySQL (MySQL Workbench)
--  La app NO usa MySQL: en el celular usa SQLite y en la nube PostgreSQL.
--  Este archivo copia los datos de la base de demostración a MySQL para
--  mostrar que el SQL es casi el mismo en los tres motores.
--  Requiere MySQL Server 8 (gratis). En Workbench: File > Open SQL Script >
--  este archivo > el rayo (Execute). Crea la base `vertex_practica`.
--  Las fechas quedan en hora UTC, igual que en la app.
-- =====================================================================
DROP DATABASE IF EXISTS vertex_practica;
CREATE DATABASE vertex_practica CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE vertex_practica;

CREATE TABLE clientes (
  id        CHAR(36)    PRIMARY KEY,
  nombre    VARCHAR(80) NOT NULL,
  telefono  VARCHAR(15),
  deleted   TINYINT(1)  NOT NULL DEFAULT 0
);

CREATE TABLE productos (
  id      CHAR(36)      PRIMARY KEY,
  nombre  VARCHAR(80)   NOT NULL,
  precio  DECIMAL(14,2) NOT NULL,
  costo   DECIMAL(14,2) NOT NULL DEFAULT 0,
  minimo  DECIMAL(12,3) NOT NULL DEFAULT 0,
  unidad  VARCHAR(4)    NOT NULL DEFAULT 'und',
  codigo  VARCHAR(40),
  deleted TINYINT(1)    NOT NULL DEFAULT 0
);

CREATE TABLE ventas (
  id         CHAR(36)      PRIMARY KEY,
  cliente_id CHAR(36),
  concepto   VARCHAR(120)  NOT NULL,
  monto      DECIMAL(14,2) NOT NULL CHECK (monto > 0),
  tipo       ENUM('ingreso','egreso','abono') NOT NULL,
  credito    TINYINT(1)    NOT NULL DEFAULT 0,
  fecha      DATETIME(3)   NOT NULL,
  pagos      JSON,
  FOREIGN KEY (cliente_id) REFERENCES clientes(id),
  INDEX ventas_fecha_idx (fecha)
);

CREATE TABLE inventario (
  id          CHAR(36)      PRIMARY KEY,
  producto_id CHAR(36)      NOT NULL,
  cantidad    DECIMAL(12,3) NOT NULL,
  motivo      VARCHAR(20)   NOT NULL,
  venta_id    CHAR(36),
  precio_unit DECIMAL(14,2),
  costo_unit  DECIMAL(14,2),
  fecha       DATETIME(3)   NOT NULL,
  FOREIGN KEY (producto_id) REFERENCES productos(id)
);

INSERT INTO clientes VALUES ('c519cc94-cc51-454b-9260-a32c78923780', 'Pedro Rincón', '3001234567', 0);
INSERT INTO clientes VALUES ('95d0b08b-2e84-4e22-a983-fd7975f0e427', 'Ana Pérez', '3157654321', 0);
INSERT INTO clientes VALUES ('8084811f-1966-44c1-bad8-54f21fa028bc', 'Luz Martínez', '3204567890', 0);
INSERT INTO productos VALUES ('9b5f2cfa-5325-4f53-af03-23e87dbae78d', 'Arroz 500 g', 2500.0, 1800.0, 10.0, 'und', '7702001000012', 0);
INSERT INTO productos VALUES ('b52531a6-d5d0-4ae5-8def-e4386e2b9284', 'Acetaminofén x10', 3000.0, 1900.0, 5.0, 'und', '', 0);
INSERT INTO productos VALUES ('b0a6b96d-f202-4c1f-bebf-b1e4ef2bc780', 'Sal mineralizada 25 kg', 48000.0, 36000.0, 4.0, 'und', '', 0);
INSERT INTO productos VALUES ('cc9c720a-a2af-4ffc-a377-592798b38970', 'Queso campesino', 24000.0, 18000.0, 2.0, 'kg', '', 0);
INSERT INTO productos VALUES ('216f0101-c4ea-48c8-8874-44c1a1681f26', 'Domicilio', 3000.0, 0.0, 0.0, 'serv', '', 0);
INSERT INTO ventas VALUES ('998f1d31-8a9b-4f2e-9b0e-25b3b57e9d89', 'c519cc94-cc51-454b-9260-a32c78923780', 'Purina 40 kg x2', 236000.0, 'ingreso', 1, '2026-08-15 15:00:00.000', NULL);
INSERT INTO ventas VALUES ('43fb17da-4a19-4225-b2b4-7bb7aa5c7ca8', 'c519cc94-cc51-454b-9260-a32c78923780', 'Abono', 150000.0, 'abono', 0, '2026-09-29 15:00:00.000', '[{"medio": "nequi", "monto": 150000.0}]');
INSERT INTO ventas VALUES ('0457b525-e221-41f9-b61c-f01e67e56472', 'c519cc94-cc51-454b-9260-a32c78923780', 'Alambre de púas', 92000.0, 'ingreso', 1, '2026-10-11 15:00:00.000', NULL);
INSERT INTO ventas VALUES ('aa9435bd-83fc-48f3-a216-24193d34f82b', '95d0b08b-2e84-4e22-a983-fd7975f0e427', 'Mercado de la semana', 64000.0, 'ingreso', 1, '2026-10-29 15:00:00.000', NULL);
INSERT INTO ventas VALUES ('eb99b78d-15b3-4a37-b0a2-7a03f4f4faab', NULL, 'Venta mostrador', 11500.0, 'ingreso', 0, '2026-11-05 13:15:00.000', '[{"medio": "daviplata", "monto": 11500.0}]');
INSERT INTO ventas VALUES ('02b09002-ca17-4c8d-ac60-8e7f2359ae70', NULL, '4 × Arroz 500 g, 1 × Acetaminofén x10', 13000.0, 'ingreso', 0, '2026-11-05 16:00:00.000', '[{"medio": "efectivo", "monto": 13000.0}]');
INSERT INTO ventas VALUES ('ca351d29-ad09-4b89-b560-9516f3b9a35f', NULL, 'Venta mostrador', 22000.0, 'ingreso', 0, '2026-11-05 16:15:00.000', '[{"medio": "efectivo", "monto": 22000.0}]');
INSERT INTO ventas VALUES ('5844d31c-a6dc-48d7-8b01-158dd2c7652a', NULL, 'Venta mostrador', 32500.0, 'ingreso', 0, '2026-11-05 19:15:00.000', '[{"medio": "nequi", "monto": 32500.0}]');
INSERT INTO ventas VALUES ('727f6ed2-7982-4061-8b1d-2f69daac820b', '8084811f-1966-44c1-bad8-54f21fa028bc', '0.75 × Queso campesino', 18000.0, 'ingreso', 1, '2026-11-05 21:00:00.000', NULL);
INSERT INTO ventas VALUES ('6941fcad-e341-4253-a143-1391b31b89fd', NULL, 'Venta mostrador', 11500.0, 'ingreso', 0, '2026-11-05 22:15:00.000', '[{"medio": "efectivo", "monto": 11500.0}]');
INSERT INTO ventas VALUES ('3c1d7829-1332-4d4a-874a-f15f40725fbc', NULL, 'Venta mostrador', 18500.0, 'ingreso', 0, '2026-11-06 13:15:00.000', '[{"medio": "tarjeta_debito", "monto": 18500.0}]');
INSERT INTO ventas VALUES ('52a39e51-ed85-49a0-9f6a-bb430b07308f', NULL, '4 × Arroz 500 g, 1 × Acetaminofén x10', 13000.0, 'ingreso', 0, '2026-11-06 16:00:00.000', '[{"medio": "efectivo", "monto": 5000.0}, {"medio": "nequi", "monto": 8000.0}]');
INSERT INTO ventas VALUES ('6055d797-f1e4-4c78-a86a-d0dd6db18c47', NULL, 'Venta mostrador', 29000.0, 'ingreso', 0, '2026-11-06 16:15:00.000', '[{"medio": "daviplata", "monto": 29000.0}]');
INSERT INTO ventas VALUES ('a1b32bab-1489-4139-8d8d-92ddd992586f', NULL, 'Venta mostrador', 8000.0, 'ingreso', 0, '2026-11-06 19:15:00.000', '[{"medio": "efectivo", "monto": 8000.0}]');
INSERT INTO ventas VALUES ('49a4f08d-c303-4fe0-a0a9-700c91e86c24', NULL, '1 × Sal mineralizada 25 kg', 48000.0, 'ingreso', 0, '2026-11-06 22:00:00.000', '[{"medio": "bancolombia", "monto": 48000.0}]');
INSERT INTO ventas VALUES ('dcd637f5-bd81-4d7b-9cd6-9574443aa138', NULL, 'Venta mostrador', 18500.0, 'ingreso', 0, '2026-11-06 22:15:00.000', '[{"medio": "nequi", "monto": 18500.0}]');
INSERT INTO ventas VALUES ('7c5edbe4-d15a-4936-a2e3-58506640044b', NULL, 'Venta mostrador', 25500.0, 'ingreso', 0, '2026-11-07 13:15:00.000', '[{"medio": "efectivo", "monto": 25500.0}]');
INSERT INTO ventas VALUES ('c05e732b-14d3-44da-9ef8-15112f67e76f', NULL, '4 × Arroz 500 g, 1 × Acetaminofén x10', 13000.0, 'ingreso', 0, '2026-11-07 16:00:00.000', '[{"medio": "efectivo", "monto": 13000.0}]');
INSERT INTO ventas VALUES ('607c2b5e-3df4-4a88-9b6a-44535ecfe9f1', NULL, 'Venta mostrador', 36000.0, 'ingreso', 0, '2026-11-07 16:15:00.000', '[{"medio": "tarjeta_debito", "monto": 36000.0}]');
INSERT INTO ventas VALUES ('ab01e382-c8b1-4ad4-8bef-fe2e89b372d4', NULL, 'Venta mostrador', 15000.0, 'ingreso', 0, '2026-11-07 19:15:00.000', '[{"medio": "daviplata", "monto": 15000.0}]');
INSERT INTO ventas VALUES ('c003bf64-4cab-4efd-ab2d-132073ffcbb5', NULL, 'Venta mostrador', 25500.0, 'ingreso', 0, '2026-11-07 22:15:00.000', '[{"medio": "efectivo", "monto": 25500.0}]');
INSERT INTO ventas VALUES ('e21ef59b-ace6-42ab-a322-0cbcff8035bf', NULL, 'Venta mostrador', 32500.0, 'ingreso', 0, '2026-11-08 13:15:00.000', '[{"medio": "bancolombia", "monto": 32500.0}]');
INSERT INTO ventas VALUES ('123ffa54-f1fd-4a0e-b7ed-806b2fae57ab', NULL, '4 × Arroz 500 g, 1 × Acetaminofén x10', 13000.0, 'ingreso', 0, '2026-11-08 16:00:00.000', '[{"medio": "efectivo", "monto": 5000.0}, {"medio": "nequi", "monto": 8000.0}]');
INSERT INTO ventas VALUES ('ef694df4-5de0-4b4b-a23d-95184e8de774', NULL, 'Venta mostrador', 11500.0, 'ingreso', 0, '2026-11-08 16:15:00.000', '[{"medio": "efectivo", "monto": 11500.0}]');
INSERT INTO ventas VALUES ('68c66ac4-55da-4eb7-abbf-bf5bb2df6c8d', NULL, 'Venta mostrador', 22000.0, 'ingreso', 0, '2026-11-08 19:15:00.000', '[{"medio": "tarjeta_debito", "monto": 22000.0}]');
INSERT INTO ventas VALUES ('46b7368d-d388-465b-8c32-b203ffc09a2a', NULL, 'Venta mostrador', 32500.0, 'ingreso', 0, '2026-11-08 22:15:00.000', '[{"medio": "daviplata", "monto": 32500.0}]');
INSERT INTO ventas VALUES ('d292ae73-f8bf-4ad4-9a66-bc507b985982', NULL, 'Pago al preventista', 180000.0, 'egreso', 0, '2026-11-08 23:00:00.000', '[{"medio": "efectivo", "monto": 180000.0}]');
INSERT INTO ventas VALUES ('7d2c9e02-9ecd-472d-af01-5788f9ab99dd', NULL, 'Venta mostrador', 8000.0, 'ingreso', 0, '2026-11-09 13:15:00.000', '[{"medio": "efectivo", "monto": 8000.0}]');
INSERT INTO ventas VALUES ('c96e9051-260f-443e-a8d8-be3bffc310e0', NULL, '4 × Arroz 500 g, 1 × Acetaminofén x10', 13000.0, 'ingreso', 0, '2026-11-09 16:00:00.000', '[{"medio": "efectivo", "monto": 13000.0}]');
INSERT INTO ventas VALUES ('130f9a90-843f-4056-b550-acaf229c1e90', NULL, 'Venta mostrador', 18500.0, 'ingreso', 0, '2026-11-09 16:15:00.000', '[{"medio": "bancolombia", "monto": 18500.0}]');
INSERT INTO ventas VALUES ('ae457e3d-7320-40cc-9b22-72fd6a10e715', NULL, 'Venta mostrador', 29000.0, 'ingreso', 0, '2026-11-09 19:15:00.000', '[{"medio": "efectivo", "monto": 29000.0}]');
INSERT INTO ventas VALUES ('08cb4c3f-ca5d-4b10-89c7-47e062622bec', '8084811f-1966-44c1-bad8-54f21fa028bc', '0.75 × Queso campesino', 18000.0, 'ingreso', 1, '2026-11-09 21:00:00.000', NULL);
INSERT INTO ventas VALUES ('0935127f-0060-4654-a4a7-372e582cddcf', NULL, 'Venta mostrador', 8000.0, 'ingreso', 0, '2026-11-09 22:15:00.000', '[{"medio": "tarjeta_debito", "monto": 8000.0}]');
INSERT INTO ventas VALUES ('930363eb-96de-4323-9725-c09f84189e01', NULL, 'Venta mostrador', 15000.0, 'ingreso', 0, '2026-11-10 13:15:00.000', '[{"medio": "nequi", "monto": 15000.0}]');
INSERT INTO ventas VALUES ('9a0a542d-b2f4-4e1a-a32d-08f14ec16ac4', NULL, '4 × Arroz 500 g, 1 × Acetaminofén x10', 13000.0, 'ingreso', 0, '2026-11-10 16:00:00.000', '[{"medio": "efectivo", "monto": 5000.0}, {"medio": "nequi", "monto": 8000.0}]');
INSERT INTO ventas VALUES ('7d61a694-7f20-4fe9-9184-74fef13fd6bf', NULL, 'Venta mostrador', 25500.0, 'ingreso', 0, '2026-11-10 16:15:00.000', '[{"medio": "efectivo", "monto": 25500.0}]');
INSERT INTO ventas VALUES ('18b7309d-a3f0-4183-bc43-f0ee8cadc3c3', NULL, 'Venta mostrador', 36000.0, 'ingreso', 0, '2026-11-10 19:15:00.000', '[{"medio": "bancolombia", "monto": 36000.0}]');
INSERT INTO ventas VALUES ('b08adf40-3d84-480d-a7dc-e8eeacfe0333', NULL, 'Venta mostrador', 15000.0, 'ingreso', 0, '2026-11-10 22:15:00.000', '[{"medio": "efectivo", "monto": 15000.0}]');
INSERT INTO ventas VALUES ('5ea70c9d-9fed-4747-bb12-69defe13b9a8', NULL, 'Venta mostrador', 22000.0, 'ingreso', 0, '2026-11-11 13:15:00.000', '[{"medio": "efectivo", "monto": 22000.0}]');
INSERT INTO ventas VALUES ('be07837a-5f51-4f67-b5b9-9e7e302a09b4', NULL, '4 × Arroz 500 g, 1 × Acetaminofén x10', 13000.0, 'ingreso', 0, '2026-11-11 16:00:00.000', '[{"medio": "efectivo", "monto": 13000.0}]');
INSERT INTO ventas VALUES ('2036ec0d-d91b-47c3-a15a-d21fb2ae1422', NULL, 'Venta mostrador', 32500.0, 'ingreso', 0, '2026-11-11 16:15:00.000', '[{"medio": "nequi", "monto": 32500.0}]');
INSERT INTO ventas VALUES ('fa1497a2-903e-4068-a458-eae8970db045', NULL, 'Venta mostrador', 11500.0, 'ingreso', 0, '2026-11-11 19:15:00.000', '[{"medio": "efectivo", "monto": 11500.0}]');
INSERT INTO ventas VALUES ('04555941-0582-49dc-92be-ff9c39147296', NULL, 'Venta mostrador', 22000.0, 'ingreso', 0, '2026-11-11 22:15:00.000', '[{"medio": "bancolombia", "monto": 22000.0}]');
INSERT INTO ventas VALUES ('8c05e9aa-aa2e-48e7-929f-393f2311c184', NULL, 'Venta mostrador', 29000.0, 'ingreso', 0, '2026-11-12 13:15:00.000', '[{"medio": "daviplata", "monto": 29000.0}]');
INSERT INTO ventas VALUES ('9687de1d-ab99-490d-a0bb-18cee84286aa', NULL, '4 × Arroz 500 g, 1 × Acetaminofén x10', 13000.0, 'ingreso', 0, '2026-11-12 16:00:00.000', '[{"medio": "efectivo", "monto": 5000.0}, {"medio": "nequi", "monto": 8000.0}]');
INSERT INTO ventas VALUES ('10b9fe0c-db20-404d-b553-7202a6160a6b', NULL, 'Venta mostrador', 8000.0, 'ingreso', 0, '2026-11-12 16:15:00.000', '[{"medio": "efectivo", "monto": 8000.0}]');
INSERT INTO ventas VALUES ('4029bc83-cc72-46fd-bec1-5ef4807ca62e', NULL, 'Venta mostrador', 18500.0, 'ingreso', 0, '2026-11-12 19:15:00.000', '[{"medio": "nequi", "monto": 18500.0}]');
INSERT INTO ventas VALUES ('85fe14ea-85e6-4af1-991d-0e2f960dc936', NULL, '1 × Sal mineralizada 25 kg', 48000.0, 'ingreso', 0, '2026-11-12 22:00:00.000', '[{"medio": "bancolombia", "monto": 48000.0}]');
INSERT INTO ventas VALUES ('a7fdaaba-8300-40a5-838c-0ca45f952950', NULL, 'Venta mostrador', 29000.0, 'ingreso', 0, '2026-11-12 22:15:00.000', '[{"medio": "efectivo", "monto": 29000.0}]');
INSERT INTO ventas VALUES ('e9612028-3e44-45ea-a15c-9fdee51939b4', NULL, 'Venta mostrador', 36000.0, 'ingreso', 0, '2026-11-13 13:15:00.000', '[{"medio": "tarjeta_debito", "monto": 36000.0}]');
INSERT INTO ventas VALUES ('7bc305b3-a776-408d-a64f-bd676ef31d88', NULL, '4 × Arroz 500 g, 1 × Acetaminofén x10', 13000.0, 'ingreso', 0, '2026-11-13 16:00:00.000', '[{"medio": "efectivo", "monto": 13000.0}]');
INSERT INTO ventas VALUES ('d0ef54d7-c4ab-40d9-8b8f-30e61390ace8', NULL, 'Venta mostrador', 15000.0, 'ingreso', 0, '2026-11-13 16:15:00.000', '[{"medio": "daviplata", "monto": 15000.0}]');
INSERT INTO ventas VALUES ('fc73afac-42a2-4543-b515-63b472bb3ce0', NULL, 'Venta mostrador', 25500.0, 'ingreso', 0, '2026-11-13 19:15:00.000', '[{"medio": "efectivo", "monto": 25500.0}]');
INSERT INTO ventas VALUES ('72fecb7a-fc94-46ce-b32c-affeb3ce7379', '8084811f-1966-44c1-bad8-54f21fa028bc', '0.75 × Queso campesino', 18000.0, 'ingreso', 1, '2026-11-13 21:00:00.000', NULL);
INSERT INTO ventas VALUES ('ffa95a05-39f3-4f38-b02c-51ad37f6a488', NULL, 'Venta mostrador', 36000.0, 'ingreso', 0, '2026-11-13 22:15:00.000', '[{"medio": "nequi", "monto": 36000.0}]');
INSERT INTO ventas VALUES ('3ef0038e-1761-4503-a0d4-c8243d740f1b', NULL, 'Pago al preventista', 180000.0, 'egreso', 0, '2026-11-13 23:00:00.000', '[{"medio": "efectivo", "monto": 180000.0}]');
INSERT INTO ventas VALUES ('d3f63c4d-5d04-4c04-ae0f-dc7d388fc010', NULL, 'Venta mostrador', 11500.0, 'ingreso', 0, '2026-11-14 13:15:00.000', '[{"medio": "efectivo", "monto": 11500.0}]');
INSERT INTO ventas VALUES ('4279278f-fb5d-467d-8331-6b8d9d13f5e2', NULL, '4 × Arroz 500 g, 1 × Acetaminofén x10', 13000.0, 'ingreso', 0, '2026-11-14 16:00:00.000', '[{"medio": "efectivo", "monto": 5000.0}, {"medio": "nequi", "monto": 8000.0}]');
INSERT INTO ventas VALUES ('5e8533f4-5cfc-4fe4-8ce3-518fc3c039c9', NULL, 'Venta mostrador', 22000.0, 'ingreso', 0, '2026-11-14 16:15:00.000', '[{"medio": "tarjeta_debito", "monto": 22000.0}]');
INSERT INTO ventas VALUES ('ef6d447e-732a-42a9-a9b5-bc5c8719896e', NULL, 'Venta mostrador', 32500.0, 'ingreso', 0, '2026-11-14 19:15:00.000', '[{"medio": "daviplata", "monto": 32500.0}]');
INSERT INTO ventas VALUES ('5a41e5a9-8a40-4768-a540-7129a5834ce2', NULL, 'Venta mostrador', 11500.0, 'ingreso', 0, '2026-11-14 22:15:00.000', '[{"medio": "efectivo", "monto": 11500.0}]');
INSERT INTO ventas VALUES ('d4a4bd33-49a7-4b90-8105-8913c83ef9b6', NULL, 'Venta mostrador', 18500.0, 'ingreso', 0, '2026-11-15 13:15:00.000', '[{"medio": "bancolombia", "monto": 18500.0}]');
INSERT INTO ventas VALUES ('ca7e0d15-5aa5-4cf1-9d4a-4f4701cc2dd3', '95d0b08b-2e84-4e22-a983-fd7975f0e427', 'Abono', 20000.0, 'abono', 0, '2026-11-15 15:00:00.000', '[{"medio": "efectivo", "monto": 20000.0}]');
INSERT INTO ventas VALUES ('3f9023ae-d926-4e36-a0d4-830308b600f7', NULL, '4 × Arroz 500 g, 1 × Acetaminofén x10', 13000.0, 'ingreso', 0, '2026-11-15 16:00:00.000', '[{"medio": "efectivo", "monto": 13000.0}]');
INSERT INTO ventas VALUES ('3da71cbc-4602-4d87-9fab-a6b6af9979da', NULL, 'Venta mostrador', 29000.0, 'ingreso', 0, '2026-11-15 16:15:00.000', '[{"medio": "efectivo", "monto": 29000.0}]');
INSERT INTO ventas VALUES ('2937f1d5-647d-4282-a0a6-bbdceead5a48', NULL, 'Venta mostrador', 8000.0, 'ingreso', 0, '2026-11-15 19:15:00.000', '[{"medio": "tarjeta_debito", "monto": 8000.0}]');
INSERT INTO ventas VALUES ('31348af9-b1ab-4ad3-94a5-e236e56ea489', NULL, 'Venta mostrador', 18500.0, 'ingreso', 0, '2026-11-15 22:15:00.000', '[{"medio": "daviplata", "monto": 18500.0}]');
INSERT INTO ventas VALUES ('4c56eb49-87ad-49df-990a-5fabdf2f03a9', NULL, 'Venta mostrador', 25500.0, 'ingreso', 0, '2026-11-16 13:15:00.000', '[{"medio": "efectivo", "monto": 25500.0}]');
INSERT INTO ventas VALUES ('7348ff1d-f2ab-48cb-a224-11dda472efb6', NULL, '4 × Arroz 500 g, 1 × Acetaminofén x10', 13000.0, 'ingreso', 0, '2026-11-16 16:00:00.000', '[{"medio": "efectivo", "monto": 5000.0}, {"medio": "nequi", "monto": 8000.0}]');
INSERT INTO ventas VALUES ('5859c9d8-271c-4584-ad1c-926f56d872e6', NULL, 'Venta mostrador', 36000.0, 'ingreso', 0, '2026-11-16 16:15:00.000', '[{"medio": "bancolombia", "monto": 36000.0}]');
INSERT INTO ventas VALUES ('a03c5638-a491-4d40-adda-87146a17de1c', NULL, 'Venta mostrador', 15000.0, 'ingreso', 0, '2026-11-16 19:15:00.000', '[{"medio": "efectivo", "monto": 15000.0}]');
INSERT INTO ventas VALUES ('283c7f33-6fa2-49ae-820c-f229f8449c1b', NULL, 'Venta mostrador', 25500.0, 'ingreso', 0, '2026-11-16 22:15:00.000', '[{"medio": "tarjeta_debito", "monto": 25500.0}]');
INSERT INTO ventas VALUES ('33109823-902d-4d54-adac-7fa8417d261d', NULL, 'Venta mostrador', 32500.0, 'ingreso', 0, '2026-11-17 13:15:00.000', '[{"medio": "nequi", "monto": 32500.0}]');
INSERT INTO ventas VALUES ('8d77e641-63d9-4b59-b151-249a7ca3a6b1', NULL, '4 × Arroz 500 g, 1 × Acetaminofén x10', 13000.0, 'ingreso', 0, '2026-11-17 16:00:00.000', '[{"medio": "efectivo", "monto": 13000.0}]');
INSERT INTO ventas VALUES ('c0e89c24-20f2-4cca-8247-407454c7da7b', NULL, 'Venta mostrador', 11500.0, 'ingreso', 0, '2026-11-17 16:15:00.000', '[{"medio": "efectivo", "monto": 11500.0}]');
INSERT INTO ventas VALUES ('9f0312a8-42a2-447e-b775-3c430f2075d2', NULL, 'Venta mostrador', 22000.0, 'ingreso', 0, '2026-11-17 19:15:00.000', '[{"medio": "bancolombia", "monto": 22000.0}]');
INSERT INTO ventas VALUES ('099e1d29-9856-45ab-857b-13d420e00b50', '8084811f-1966-44c1-bad8-54f21fa028bc', '0.75 × Queso campesino', 18000.0, 'ingreso', 1, '2026-11-17 21:00:00.000', NULL);
INSERT INTO ventas VALUES ('aeeae57d-ee40-4217-a9bb-536be7c667b7', NULL, 'Venta mostrador', 32500.0, 'ingreso', 0, '2026-11-17 22:15:00.000', '[{"medio": "efectivo", "monto": 32500.0}]');
INSERT INTO ventas VALUES ('1f55dd34-f7d0-46f6-9478-02b446d281bc', NULL, 'Servicio de luz', 86000.0, 'egreso', 0, '2026-11-18 00:00:00.000', '[{"medio": "nequi", "monto": 86000.0}]');
INSERT INTO ventas VALUES ('2431598c-022e-4857-841a-73a121429cff', NULL, 'Venta mostrador', 18500.0, 'ingreso', 0, '2026-11-18 12:07:00.000', '[{"medio": "nequi", "monto": 18500.0}]');
INSERT INTO ventas VALUES ('fd86620e-a1cd-4d82-9321-b0af33b5e2b0', NULL, 'Venta mostrador', 29000.0, 'ingreso', 0, '2026-11-18 12:14:00.000', '[{"medio": "efectivo", "monto": 29000.0}]');
INSERT INTO ventas VALUES ('f9456957-0ea2-42b7-88d6-fbc1879baf46', NULL, 'Venta mostrador', 8000.0, 'ingreso', 0, '2026-11-18 12:21:00.000', '[{"medio": "bancolombia", "monto": 8000.0}]');
INSERT INTO ventas VALUES ('816a22aa-ce70-4d65-b7ea-24cde69689a9', NULL, '1 × Sal mineralizada 25 kg', 48000.0, 'ingreso', 0, '2026-11-18 12:28:00.000', '[{"medio": "bancolombia", "monto": 48000.0}]');
INSERT INTO ventas VALUES ('f1ecd494-4d87-41df-86fa-3ddbac3dd035', NULL, 'Pago al preventista', 180000.0, 'egreso', 0, '2026-11-18 12:35:00.000', '[{"medio": "efectivo", "monto": 180000.0}]');
INSERT INTO ventas VALUES ('80fce04b-0494-4545-8d39-8262aa3604c5', NULL, 'Venta mostrador', 8000.0, 'ingreso', 0, '2026-11-18 13:15:00.000', '[{"medio": "efectivo", "monto": 8000.0}]');
INSERT INTO ventas VALUES ('d18193dc-72ac-4ba5-a702-3f46debb149d', NULL, '4 × Arroz 500 g, 1 × Acetaminofén x10', 13000.0, 'ingreso', 0, '2026-11-18 16:00:00.000', '[{"medio": "efectivo", "monto": 5000.0}, {"medio": "nequi", "monto": 8000.0}]');
INSERT INTO inventario VALUES ('75dc3de2-f0fa-44c5-88f3-d13a65cd8397', '9b5f2cfa-5325-4f53-af03-23e87dbae78d', 120.0, 'entrada', NULL, NULL, 1800.0, '2026-08-20 15:00:00.000');
INSERT INTO inventario VALUES ('78f715d7-c871-4b49-8f0a-cd9423492490', 'b52531a6-d5d0-4ae5-8def-e4386e2b9284', 40.0, 'entrada', NULL, NULL, 1900.0, '2026-08-20 15:00:00.000');
INSERT INTO inventario VALUES ('3f1c4b81-db33-466c-a4f9-08a50435e679', 'b0a6b96d-f202-4c1f-bebf-b1e4ef2bc780', 6.0, 'entrada', NULL, NULL, 36000.0, '2026-08-20 15:00:00.000');
INSERT INTO inventario VALUES ('e1e9ebaa-abd8-4d78-ac7b-5573aab953c0', 'cc9c720a-a2af-4ffc-a377-592798b38970', 8.0, 'entrada', NULL, NULL, 18000.0, '2026-08-20 15:00:00.000');
INSERT INTO inventario VALUES ('78587849-1882-4af0-a73c-bf3c3513a2d5', '9b5f2cfa-5325-4f53-af03-23e87dbae78d', -4.0, 'venta', '02b09002-ca17-4c8d-ac60-8e7f2359ae70', 2500.0, 1800.0, '2026-11-05 16:00:00.000');
INSERT INTO inventario VALUES ('8ab994ad-54e5-4eee-979d-99db12244dbc', 'b52531a6-d5d0-4ae5-8def-e4386e2b9284', -1.0, 'venta', '02b09002-ca17-4c8d-ac60-8e7f2359ae70', 3000.0, 1900.0, '2026-11-05 16:00:00.000');
INSERT INTO inventario VALUES ('8301fb3b-f9f8-411a-aa6f-3a7899d38970', 'cc9c720a-a2af-4ffc-a377-592798b38970', -0.75, 'venta', '727f6ed2-7982-4061-8b1d-2f69daac820b', 24000.0, 18000.0, '2026-11-05 21:00:00.000');
INSERT INTO inventario VALUES ('729275eb-12e9-4859-aa03-9394adb10759', '9b5f2cfa-5325-4f53-af03-23e87dbae78d', -4.0, 'venta', '52a39e51-ed85-49a0-9f6a-bb430b07308f', 2500.0, 1800.0, '2026-11-06 16:00:00.000');
INSERT INTO inventario VALUES ('59ae03f7-78b4-4986-9bab-88960ce81648', 'b52531a6-d5d0-4ae5-8def-e4386e2b9284', -1.0, 'venta', '52a39e51-ed85-49a0-9f6a-bb430b07308f', 3000.0, 1900.0, '2026-11-06 16:00:00.000');
INSERT INTO inventario VALUES ('68f067a5-c442-4823-a919-b4a396d2839f', 'b0a6b96d-f202-4c1f-bebf-b1e4ef2bc780', -1.0, 'venta', '49a4f08d-c303-4fe0-a0a9-700c91e86c24', 48000.0, 36000.0, '2026-11-06 22:00:00.000');
INSERT INTO inventario VALUES ('835f3204-b893-4ff4-a204-4f614d286653', '9b5f2cfa-5325-4f53-af03-23e87dbae78d', -4.0, 'venta', 'c05e732b-14d3-44da-9ef8-15112f67e76f', 2500.0, 1800.0, '2026-11-07 16:00:00.000');
INSERT INTO inventario VALUES ('b08235cf-3c85-4c13-a8a2-c5e64587ac05', 'b52531a6-d5d0-4ae5-8def-e4386e2b9284', -1.0, 'venta', 'c05e732b-14d3-44da-9ef8-15112f67e76f', 3000.0, 1900.0, '2026-11-07 16:00:00.000');
INSERT INTO inventario VALUES ('a7ab538b-7e03-4d3a-815b-0820cfe0ec40', '9b5f2cfa-5325-4f53-af03-23e87dbae78d', -4.0, 'venta', '123ffa54-f1fd-4a0e-b7ed-806b2fae57ab', 2500.0, 1800.0, '2026-11-08 16:00:00.000');
INSERT INTO inventario VALUES ('5bcf0091-d7ba-4592-a3fd-20c696384f48', 'b52531a6-d5d0-4ae5-8def-e4386e2b9284', -1.0, 'venta', '123ffa54-f1fd-4a0e-b7ed-806b2fae57ab', 3000.0, 1900.0, '2026-11-08 16:00:00.000');
INSERT INTO inventario VALUES ('93858520-6faa-4d13-9b99-72c4a4bd1e99', '9b5f2cfa-5325-4f53-af03-23e87dbae78d', -4.0, 'venta', 'c96e9051-260f-443e-a8d8-be3bffc310e0', 2500.0, 1800.0, '2026-11-09 16:00:00.000');
INSERT INTO inventario VALUES ('92026a06-ec4a-48d6-8fed-c3bbe1acbed7', 'b52531a6-d5d0-4ae5-8def-e4386e2b9284', -1.0, 'venta', 'c96e9051-260f-443e-a8d8-be3bffc310e0', 3000.0, 1900.0, '2026-11-09 16:00:00.000');
INSERT INTO inventario VALUES ('34abea5f-c4d9-401d-9b85-95d9788741cb', 'cc9c720a-a2af-4ffc-a377-592798b38970', -0.75, 'venta', '08cb4c3f-ca5d-4b10-89c7-47e062622bec', 24000.0, 18000.0, '2026-11-09 21:00:00.000');
INSERT INTO inventario VALUES ('5a4bf9bd-bb3f-42c3-a0c3-110eeccfa851', '9b5f2cfa-5325-4f53-af03-23e87dbae78d', -4.0, 'venta', '9a0a542d-b2f4-4e1a-a32d-08f14ec16ac4', 2500.0, 1800.0, '2026-11-10 16:00:00.000');
INSERT INTO inventario VALUES ('4cdb4b88-585a-4e99-a3c4-7b0fc32678f7', 'b52531a6-d5d0-4ae5-8def-e4386e2b9284', -1.0, 'venta', '9a0a542d-b2f4-4e1a-a32d-08f14ec16ac4', 3000.0, 1900.0, '2026-11-10 16:00:00.000');
INSERT INTO inventario VALUES ('a6094482-43c2-49ab-b6a0-b47166dc17b2', '9b5f2cfa-5325-4f53-af03-23e87dbae78d', -4.0, 'venta', 'be07837a-5f51-4f67-b5b9-9e7e302a09b4', 2500.0, 1800.0, '2026-11-11 16:00:00.000');
INSERT INTO inventario VALUES ('80d94b64-01ea-45e0-858c-605847ea2507', 'b52531a6-d5d0-4ae5-8def-e4386e2b9284', -1.0, 'venta', 'be07837a-5f51-4f67-b5b9-9e7e302a09b4', 3000.0, 1900.0, '2026-11-11 16:00:00.000');
INSERT INTO inventario VALUES ('2e80a6f3-4084-4f18-86d9-23588d64ff4f', '9b5f2cfa-5325-4f53-af03-23e87dbae78d', -4.0, 'venta', '9687de1d-ab99-490d-a0bb-18cee84286aa', 2500.0, 1800.0, '2026-11-12 16:00:00.000');
INSERT INTO inventario VALUES ('1f2ce216-048b-4ba0-9138-ec6733c1266d', 'b52531a6-d5d0-4ae5-8def-e4386e2b9284', -1.0, 'venta', '9687de1d-ab99-490d-a0bb-18cee84286aa', 3000.0, 1900.0, '2026-11-12 16:00:00.000');
INSERT INTO inventario VALUES ('798b4dfd-94a6-4534-8b13-8911d1bd5232', 'b0a6b96d-f202-4c1f-bebf-b1e4ef2bc780', -1.0, 'venta', '85fe14ea-85e6-4af1-991d-0e2f960dc936', 48000.0, 36000.0, '2026-11-12 22:00:00.000');
INSERT INTO inventario VALUES ('bbd58755-d91a-43f4-b340-4448f63d2a66', '9b5f2cfa-5325-4f53-af03-23e87dbae78d', -4.0, 'venta', '7bc305b3-a776-408d-a64f-bd676ef31d88', 2500.0, 1800.0, '2026-11-13 16:00:00.000');
INSERT INTO inventario VALUES ('2cb4cf3c-2f83-4d9a-8cc3-69be47da8a9e', 'b52531a6-d5d0-4ae5-8def-e4386e2b9284', -1.0, 'venta', '7bc305b3-a776-408d-a64f-bd676ef31d88', 3000.0, 1900.0, '2026-11-13 16:00:00.000');
INSERT INTO inventario VALUES ('a3d5b81f-d586-40f6-9b99-0cb53aa4d6d3', 'cc9c720a-a2af-4ffc-a377-592798b38970', -0.75, 'venta', '72fecb7a-fc94-46ce-b32c-affeb3ce7379', 24000.0, 18000.0, '2026-11-13 21:00:00.000');
INSERT INTO inventario VALUES ('57e37227-96af-4689-9448-23468fabad6f', '9b5f2cfa-5325-4f53-af03-23e87dbae78d', -4.0, 'venta', '4279278f-fb5d-467d-8331-6b8d9d13f5e2', 2500.0, 1800.0, '2026-11-14 16:00:00.000');
INSERT INTO inventario VALUES ('114c3781-67ea-40cb-abfd-65740bb2b361', 'b52531a6-d5d0-4ae5-8def-e4386e2b9284', -1.0, 'venta', '4279278f-fb5d-467d-8331-6b8d9d13f5e2', 3000.0, 1900.0, '2026-11-14 16:00:00.000');
INSERT INTO inventario VALUES ('f1fc776c-ecd0-4f78-9187-d19d9d15432a', '9b5f2cfa-5325-4f53-af03-23e87dbae78d', -4.0, 'venta', '3f9023ae-d926-4e36-a0d4-830308b600f7', 2500.0, 1800.0, '2026-11-15 16:00:00.000');
INSERT INTO inventario VALUES ('a2876951-97d4-4bf3-9149-1b1242d77a88', 'b52531a6-d5d0-4ae5-8def-e4386e2b9284', -1.0, 'venta', '3f9023ae-d926-4e36-a0d4-830308b600f7', 3000.0, 1900.0, '2026-11-15 16:00:00.000');
INSERT INTO inventario VALUES ('b1c1fe7a-9c50-4d9e-b9a7-ca1d2e8f685f', '9b5f2cfa-5325-4f53-af03-23e87dbae78d', -4.0, 'venta', '7348ff1d-f2ab-48cb-a224-11dda472efb6', 2500.0, 1800.0, '2026-11-16 16:00:00.000');
INSERT INTO inventario VALUES ('17a718e7-a7cf-4cfe-a4e4-916c959a038f', 'b52531a6-d5d0-4ae5-8def-e4386e2b9284', -1.0, 'venta', '7348ff1d-f2ab-48cb-a224-11dda472efb6', 3000.0, 1900.0, '2026-11-16 16:00:00.000');
INSERT INTO inventario VALUES ('29e8d1b0-da8c-4aef-9a71-9511b34278b6', '9b5f2cfa-5325-4f53-af03-23e87dbae78d', -4.0, 'venta', '8d77e641-63d9-4b59-b151-249a7ca3a6b1', 2500.0, 1800.0, '2026-11-17 16:00:00.000');
INSERT INTO inventario VALUES ('22b3f5ef-edcd-41a3-a18e-4a7e6e27cb39', 'b52531a6-d5d0-4ae5-8def-e4386e2b9284', -1.0, 'venta', '8d77e641-63d9-4b59-b151-249a7ca3a6b1', 3000.0, 1900.0, '2026-11-17 16:00:00.000');
INSERT INTO inventario VALUES ('1c9a366d-058c-446a-aa3e-7ddf02650f17', 'cc9c720a-a2af-4ffc-a377-592798b38970', -0.75, 'venta', '099e1d29-9856-45ab-857b-13d420e00b50', 24000.0, 18000.0, '2026-11-17 21:00:00.000');
INSERT INTO inventario VALUES ('5b9a352d-60d5-4d59-a48d-bc263f28e769', 'b0a6b96d-f202-4c1f-bebf-b1e4ef2bc780', -1.0, 'venta', '816a22aa-ce70-4d65-b7ea-24cde69689a9', 48000.0, 36000.0, '2026-11-18 12:28:00.000');
INSERT INTO inventario VALUES ('ddc5ad0b-639b-4a25-8404-b2223593b9da', '9b5f2cfa-5325-4f53-af03-23e87dbae78d', -4.0, 'venta', 'd18193dc-72ac-4ba5-a702-3f46debb149d', 2500.0, 1800.0, '2026-11-18 16:00:00.000');
INSERT INTO inventario VALUES ('f6b4f6d3-739c-4411-b55d-37b6e6e311af', 'b52531a6-d5d0-4ae5-8def-e4386e2b9284', -1.0, 'venta', 'd18193dc-72ac-4ba5-a702-3f46debb149d', 3000.0, 1900.0, '2026-11-18 16:00:00.000');

-- =====================================================================
--  CONSULTAS (las mismas de la base local, en el idioma de MySQL)
-- =====================================================================

-- 1. Ventas por día (hora de Colombia = UTC - 5 horas)
SELECT DATE(DATE_SUB(fecha, INTERVAL 5 HOUR)) AS dia, COUNT(*) AS numero, SUM(monto) AS total
FROM ventas WHERE tipo = 'ingreso'
GROUP BY dia ORDER BY dia DESC LIMIT 7;

-- 2. Cuánto entró por cada medio de pago (JSON_TABLE lee la lista de pagos)
SELECT p.medio, SUM(p.monto) AS total
FROM ventas v,
     JSON_TABLE(v.pagos, '$[*]' COLUMNS (medio VARCHAR(20) PATH '$.medio',
                                         monto DECIMAL(14,2) PATH '$.monto')) AS p
WHERE v.tipo IN ('ingreso', 'abono')
GROUP BY p.medio ORDER BY total DESC;

-- 3. Quién debe y cuánto
SELECT c.nombre,
       SUM(CASE WHEN v.tipo = 'ingreso' AND v.credito = 1 THEN v.monto
                WHEN v.tipo = 'abono' THEN -v.monto ELSE 0 END) AS saldo
FROM clientes c JOIN ventas v ON v.cliente_id = c.id
GROUP BY c.id, c.nombre HAVING saldo > 0 ORDER BY saldo DESC;

-- 4. Inventario: existencia = suma de movimientos
SELECT p.nombre, p.unidad, COALESCE(SUM(i.cantidad), 0) AS existencia, p.minimo
FROM productos p LEFT JOIN inventario i ON i.producto_id = p.id
WHERE p.deleted = 0 AND p.unidad <> 'serv'
GROUP BY p.id, p.nombre, p.unidad, p.minimo ORDER BY existencia;

-- 5. Productos más vendidos y su ganancia
SELECT p.nombre, SUM(-i.cantidad) AS vendidos, SUM(-i.cantidad * (i.precio_unit - i.costo_unit)) AS ganancia
FROM inventario i JOIN productos p ON p.id = i.producto_id
WHERE i.motivo = 'venta'
GROUP BY p.id, p.nombre ORDER BY vendidos DESC;
