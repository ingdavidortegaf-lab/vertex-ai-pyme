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

INSERT INTO clientes VALUES ('3508c732-cd76-4074-80bf-6ff0bce4f48c', 'Pedro Rincón', '3001234567', 0);
INSERT INTO clientes VALUES ('25a674e6-01f4-4507-84e4-a09ca9dc936a', 'Ana Pérez', '3157654321', 0);
INSERT INTO clientes VALUES ('9ef10ffc-918b-4a37-8689-d8088f0c2a3d', 'Luz Martínez', '3204567890', 0);
INSERT INTO productos VALUES ('62b0d57e-3013-459c-b2a5-fb3a16fd0160', 'Arroz 500 g', 2500.0, 1800.0, 10.0, 'und', '7702001000012', 0);
INSERT INTO productos VALUES ('263f2814-91ab-4ba1-b99b-8884ee6f8efb', 'Acetaminofén x10', 3000.0, 1900.0, 5.0, 'und', '', 0);
INSERT INTO productos VALUES ('2204d2f7-c28d-49c9-84d7-a0ab8bfbbc07', 'Sal mineralizada 25 kg', 48000.0, 36000.0, 4.0, 'und', '', 0);
INSERT INTO productos VALUES ('b48c623b-e6fd-4c03-9403-0b5dcd975a20', 'Queso campesino', 24000.0, 18000.0, 2.0, 'kg', '', 0);
INSERT INTO productos VALUES ('61d0d6f9-a60f-47b0-9876-171d93f8f2bd', 'Domicilio', 3000.0, 0.0, 0.0, 'serv', '', 0);
INSERT INTO ventas VALUES ('84f26863-0ed6-486b-ba42-69065b777d47', '3508c732-cd76-4074-80bf-6ff0bce4f48c', 'Purina 40 kg x2', 236000.0, 'ingreso', 1, '2026-08-15 15:00:00.000', NULL);
INSERT INTO ventas VALUES ('2d5faa3f-a640-48dd-a605-0b96e645838f', '3508c732-cd76-4074-80bf-6ff0bce4f48c', 'Abono', 150000.0, 'abono', 0, '2026-09-29 15:00:00.000', '[{"medio": "nequi", "monto": 150000.0}]');
INSERT INTO ventas VALUES ('899ad958-53d0-4cdd-b734-f1173b5a729c', '3508c732-cd76-4074-80bf-6ff0bce4f48c', 'Alambre de púas', 92000.0, 'ingreso', 1, '2026-10-11 15:00:00.000', NULL);
INSERT INTO ventas VALUES ('957d99a9-c759-4d05-8479-a88d07dadb46', '25a674e6-01f4-4507-84e4-a09ca9dc936a', 'Mercado de la semana', 64000.0, 'ingreso', 1, '2026-10-29 15:00:00.000', NULL);
INSERT INTO ventas VALUES ('d35492e6-ab50-4f82-9005-959bdb058fb1', NULL, 'Venta mostrador', 11500.0, 'ingreso', 0, '2026-11-05 13:15:00.000', '[{"medio": "daviplata", "monto": 11500.0}]');
INSERT INTO ventas VALUES ('465bb30e-a1fe-4173-b6fe-f23de8f2f4d1', NULL, '4 × Arroz 500 g, 1 × Acetaminofén x10', 13000.0, 'ingreso', 0, '2026-11-05 16:00:00.000', '[{"medio": "efectivo", "monto": 13000.0}]');
INSERT INTO ventas VALUES ('33d4f396-7a4e-49a1-8316-7a19554d0023', NULL, 'Venta mostrador', 22000.0, 'ingreso', 0, '2026-11-05 16:15:00.000', '[{"medio": "efectivo", "monto": 22000.0}]');
INSERT INTO ventas VALUES ('5e033497-0a41-48da-8834-86c675802b92', NULL, 'Venta mostrador', 32500.0, 'ingreso', 0, '2026-11-05 19:15:00.000', '[{"medio": "nequi", "monto": 32500.0}]');
INSERT INTO ventas VALUES ('5b65a595-946b-4b96-8951-86733b69493b', '9ef10ffc-918b-4a37-8689-d8088f0c2a3d', '0.75 × Queso campesino', 18000.0, 'ingreso', 1, '2026-11-05 21:00:00.000', NULL);
INSERT INTO ventas VALUES ('f3eca758-00a9-4297-8290-7655e1488335', NULL, 'Venta mostrador', 11500.0, 'ingreso', 0, '2026-11-05 22:15:00.000', '[{"medio": "efectivo", "monto": 11500.0}]');
INSERT INTO ventas VALUES ('1d8bed33-5953-4e7b-9455-2ad36cf61fed', NULL, 'Venta mostrador', 18500.0, 'ingreso', 0, '2026-11-06 13:15:00.000', '[{"medio": "tarjeta_debito", "monto": 18500.0}]');
INSERT INTO ventas VALUES ('48998f6f-6df7-4c0b-bb53-967f98cc0b7e', NULL, 'Compra a Distribuidora El Llano (pago parcial)', 45000.0, 'egreso', 0, '2026-11-06 14:00:00.000', '[{"medio": "efectivo", "monto": 45000.0}]');
INSERT INTO ventas VALUES ('f12551f1-414e-4834-99a4-b85e7f305841', NULL, '4 × Arroz 500 g, 1 × Acetaminofén x10', 13000.0, 'ingreso', 0, '2026-11-06 16:00:00.000', '[{"medio": "efectivo", "monto": 5000.0}, {"medio": "nequi", "monto": 8000.0}]');
INSERT INTO ventas VALUES ('56312020-6f02-4942-aa4f-df0288edf9a1', NULL, 'Venta mostrador', 29000.0, 'ingreso', 0, '2026-11-06 16:15:00.000', '[{"medio": "daviplata", "monto": 29000.0}]');
INSERT INTO ventas VALUES ('975f6628-77ac-424e-8a8d-ba3e8eeaa97e', NULL, 'Venta mostrador', 8000.0, 'ingreso', 0, '2026-11-06 19:15:00.000', '[{"medio": "efectivo", "monto": 8000.0}]');
INSERT INTO ventas VALUES ('21b3233f-a32a-4019-a464-80d1ebe484d2', NULL, '1 × Sal mineralizada 25 kg', 48000.0, 'ingreso', 0, '2026-11-06 22:00:00.000', '[{"medio": "bancolombia", "monto": 48000.0}]');
INSERT INTO ventas VALUES ('75da4650-af4e-4f04-bd49-c71e91a51872', NULL, 'Venta mostrador', 18500.0, 'ingreso', 0, '2026-11-06 22:15:00.000', '[{"medio": "nequi", "monto": 18500.0}]');
INSERT INTO ventas VALUES ('3a2f7838-8540-4779-91d9-7f42c65416fe', NULL, 'Venta mostrador', 25500.0, 'ingreso', 0, '2026-11-07 13:15:00.000', '[{"medio": "efectivo", "monto": 25500.0}]');
INSERT INTO ventas VALUES ('c6bf9b4b-f1a8-47e8-baf3-160fa1014e39', NULL, '4 × Arroz 500 g, 1 × Acetaminofén x10', 13000.0, 'ingreso', 0, '2026-11-07 16:00:00.000', '[{"medio": "efectivo", "monto": 13000.0}]');
INSERT INTO ventas VALUES ('2bc2c320-1c11-43b5-b003-3542ecb97bfd', NULL, 'Venta mostrador', 36000.0, 'ingreso', 0, '2026-11-07 16:15:00.000', '[{"medio": "tarjeta_debito", "monto": 36000.0}]');
INSERT INTO ventas VALUES ('cf4f5108-89fc-4a4c-9ffd-377c9798f3a4', NULL, 'Venta mostrador', 15000.0, 'ingreso', 0, '2026-11-07 19:15:00.000', '[{"medio": "daviplata", "monto": 15000.0}]');
INSERT INTO ventas VALUES ('e47a5eb9-9577-476c-8175-b4e7aa97563c', NULL, 'Venta mostrador', 25500.0, 'ingreso', 0, '2026-11-07 22:15:00.000', '[{"medio": "efectivo", "monto": 25500.0}]');
INSERT INTO ventas VALUES ('f68f8999-ed50-4aaf-8016-08f66bdc8f3d', NULL, 'Venta mostrador', 32500.0, 'ingreso', 0, '2026-11-08 13:15:00.000', '[{"medio": "bancolombia", "monto": 32500.0}]');
INSERT INTO ventas VALUES ('15b5a50b-4880-4617-967f-2d5dc2e5562d', NULL, '4 × Arroz 500 g, 1 × Acetaminofén x10', 13000.0, 'ingreso', 0, '2026-11-08 16:00:00.000', '[{"medio": "efectivo", "monto": 5000.0}, {"medio": "nequi", "monto": 8000.0}]');
INSERT INTO ventas VALUES ('86ff6be1-8b42-411c-b279-f554fa9aab05', NULL, 'Venta mostrador', 11500.0, 'ingreso', 0, '2026-11-08 16:15:00.000', '[{"medio": "efectivo", "monto": 11500.0}]');
INSERT INTO ventas VALUES ('90cc7fdd-f499-4b33-8fb8-6f5599d0036b', NULL, 'Venta mostrador', 22000.0, 'ingreso', 0, '2026-11-08 19:15:00.000', '[{"medio": "tarjeta_debito", "monto": 22000.0}]');
INSERT INTO ventas VALUES ('a9296b24-dbf1-4fb5-a28f-aeddc646c168', NULL, 'Venta mostrador', 32500.0, 'ingreso', 0, '2026-11-08 22:15:00.000', '[{"medio": "daviplata", "monto": 32500.0}]');
INSERT INTO ventas VALUES ('4bceec28-be2a-43ae-a630-01152f5724bd', NULL, 'Pago al preventista', 180000.0, 'egreso', 0, '2026-11-08 23:00:00.000', '[{"medio": "efectivo", "monto": 180000.0}]');
INSERT INTO ventas VALUES ('9e9d7f6b-4f14-4033-8953-88cac08bafc2', NULL, 'Venta mostrador', 8000.0, 'ingreso', 0, '2026-11-09 13:15:00.000', '[{"medio": "efectivo", "monto": 8000.0}]');
INSERT INTO ventas VALUES ('f895c140-aecd-4e96-b45b-11acaac28312', NULL, '4 × Arroz 500 g, 1 × Acetaminofén x10', 13000.0, 'ingreso', 0, '2026-11-09 16:00:00.000', '[{"medio": "efectivo", "monto": 13000.0}]');
INSERT INTO ventas VALUES ('6112879e-87b4-4515-bb6e-d607f39ec9cb', NULL, 'Venta mostrador', 18500.0, 'ingreso', 0, '2026-11-09 16:15:00.000', '[{"medio": "bancolombia", "monto": 18500.0}]');
INSERT INTO ventas VALUES ('1e0e26cf-77c9-4542-a104-d2d912625656', NULL, 'Venta mostrador', 29000.0, 'ingreso', 0, '2026-11-09 19:15:00.000', '[{"medio": "efectivo", "monto": 29000.0}]');
INSERT INTO ventas VALUES ('7b08ea59-52e5-4094-bfd4-0b72850da1b5', '9ef10ffc-918b-4a37-8689-d8088f0c2a3d', '0.75 × Queso campesino', 18000.0, 'ingreso', 1, '2026-11-09 21:00:00.000', NULL);
INSERT INTO ventas VALUES ('f11e93c8-6f5a-4fd1-84f0-2f38a225750d', NULL, 'Venta mostrador', 8000.0, 'ingreso', 0, '2026-11-09 22:15:00.000', '[{"medio": "tarjeta_debito", "monto": 8000.0}]');
INSERT INTO ventas VALUES ('cbe168f4-b7bc-497c-a06a-a73772d87427', NULL, 'Venta mostrador', 15000.0, 'ingreso', 0, '2026-11-10 13:15:00.000', '[{"medio": "nequi", "monto": 15000.0}]');
INSERT INTO ventas VALUES ('5207d9b4-b054-426b-8565-281e717a97b6', NULL, '4 × Arroz 500 g, 1 × Acetaminofén x10', 13000.0, 'ingreso', 0, '2026-11-10 16:00:00.000', '[{"medio": "efectivo", "monto": 5000.0}, {"medio": "nequi", "monto": 8000.0}]');
INSERT INTO ventas VALUES ('1e82ebaf-29c7-448a-8727-0e90b7529ff7', NULL, 'Venta mostrador', 25500.0, 'ingreso', 0, '2026-11-10 16:15:00.000', '[{"medio": "efectivo", "monto": 25500.0}]');
INSERT INTO ventas VALUES ('06244cef-d504-495a-a240-b2a359012a23', NULL, 'Venta mostrador', 36000.0, 'ingreso', 0, '2026-11-10 19:15:00.000', '[{"medio": "bancolombia", "monto": 36000.0}]');
INSERT INTO ventas VALUES ('8865f94f-aa9c-484d-ab31-aef293525f4f', NULL, 'Venta mostrador', 15000.0, 'ingreso', 0, '2026-11-10 22:15:00.000', '[{"medio": "efectivo", "monto": 15000.0}]');
INSERT INTO ventas VALUES ('c23f5375-3ed4-4ef8-ada1-ba27c6915651', NULL, 'Venta mostrador', 22000.0, 'ingreso', 0, '2026-11-11 13:15:00.000', '[{"medio": "efectivo", "monto": 22000.0}]');
INSERT INTO ventas VALUES ('fbdb69ad-0e1a-4e82-875c-a2dc0289e2fd', NULL, '4 × Arroz 500 g, 1 × Acetaminofén x10', 13000.0, 'ingreso', 0, '2026-11-11 16:00:00.000', '[{"medio": "efectivo", "monto": 13000.0}]');
INSERT INTO ventas VALUES ('aa44e189-2ea1-4658-9446-cc36415bcef8', NULL, 'Venta mostrador', 32500.0, 'ingreso', 0, '2026-11-11 16:15:00.000', '[{"medio": "nequi", "monto": 32500.0}]');
INSERT INTO ventas VALUES ('660d0f25-cff8-472d-ac35-6231690011e2', NULL, 'Venta mostrador', 11500.0, 'ingreso', 0, '2026-11-11 19:15:00.000', '[{"medio": "efectivo", "monto": 11500.0}]');
INSERT INTO ventas VALUES ('1ca19ee9-39e0-4abb-8081-6f810fcddfd9', NULL, 'Venta mostrador', 22000.0, 'ingreso', 0, '2026-11-11 22:15:00.000', '[{"medio": "bancolombia", "monto": 22000.0}]');
INSERT INTO ventas VALUES ('cd030bf8-e3dd-458e-9532-d928ae1b4a44', NULL, 'Venta mostrador', 29000.0, 'ingreso', 0, '2026-11-12 13:15:00.000', '[{"medio": "daviplata", "monto": 29000.0}]');
INSERT INTO ventas VALUES ('08e38a88-d6b4-400b-9843-f1e87bcd63ff', NULL, '4 × Arroz 500 g, 1 × Acetaminofén x10', 13000.0, 'ingreso', 0, '2026-11-12 16:00:00.000', '[{"medio": "efectivo", "monto": 5000.0}, {"medio": "nequi", "monto": 8000.0}]');
INSERT INTO ventas VALUES ('e096edce-8e00-424d-9b58-0ed25df3e779', NULL, 'Venta mostrador', 8000.0, 'ingreso', 0, '2026-11-12 16:15:00.000', '[{"medio": "efectivo", "monto": 8000.0}]');
INSERT INTO ventas VALUES ('a94162be-305a-41d9-a6e9-41d0490ec02c', NULL, 'Venta mostrador', 18500.0, 'ingreso', 0, '2026-11-12 19:15:00.000', '[{"medio": "nequi", "monto": 18500.0}]');
INSERT INTO ventas VALUES ('806c4915-5846-4f52-8c20-d8fe9314abee', NULL, '1 × Sal mineralizada 25 kg', 48000.0, 'ingreso', 0, '2026-11-12 22:00:00.000', '[{"medio": "bancolombia", "monto": 48000.0}]');
INSERT INTO ventas VALUES ('79d06c08-d7aa-4eeb-8772-0b0ee7fb8b2a', NULL, 'Venta mostrador', 29000.0, 'ingreso', 0, '2026-11-12 22:15:00.000', '[{"medio": "efectivo", "monto": 29000.0}]');
INSERT INTO ventas VALUES ('8b7581b5-0eb4-4fd9-a74c-2fea47d6b464', NULL, 'Venta mostrador', 36000.0, 'ingreso', 0, '2026-11-13 13:15:00.000', '[{"medio": "tarjeta_debito", "monto": 36000.0}]');
INSERT INTO ventas VALUES ('7fada189-347e-4a41-a797-74c1a090b46a', NULL, '4 × Arroz 500 g, 1 × Acetaminofén x10', 13000.0, 'ingreso', 0, '2026-11-13 16:00:00.000', '[{"medio": "efectivo", "monto": 13000.0}]');
INSERT INTO ventas VALUES ('d5b40ec8-f40f-4fd0-8f50-79f3be46c9d0', NULL, 'Venta mostrador', 15000.0, 'ingreso', 0, '2026-11-13 16:15:00.000', '[{"medio": "daviplata", "monto": 15000.0}]');
INSERT INTO ventas VALUES ('7123bb56-1d6b-4d22-8ca9-8a466fc9632d', NULL, 'Venta mostrador', 25500.0, 'ingreso', 0, '2026-11-13 19:15:00.000', '[{"medio": "efectivo", "monto": 25500.0}]');
INSERT INTO ventas VALUES ('5c781be7-308e-44dd-a622-6890271597d4', NULL, 'Abono a Distribuidora El Llano', 20000.0, 'egreso', 0, '2026-11-13 20:00:00.000', '[{"medio": "nequi", "monto": 20000.0}]');
INSERT INTO ventas VALUES ('b4cfd839-4e3e-4360-8d03-4ce255dd36c1', '9ef10ffc-918b-4a37-8689-d8088f0c2a3d', '0.75 × Queso campesino', 18000.0, 'ingreso', 1, '2026-11-13 21:00:00.000', NULL);
INSERT INTO ventas VALUES ('77cbc600-db66-4055-9411-76f1d12c174d', NULL, 'Venta mostrador', 36000.0, 'ingreso', 0, '2026-11-13 22:15:00.000', '[{"medio": "nequi", "monto": 36000.0}]');
INSERT INTO ventas VALUES ('9b8f4c67-9959-47a0-bc9c-d30fc0119200', NULL, 'Pago al preventista', 180000.0, 'egreso', 0, '2026-11-13 23:00:00.000', '[{"medio": "efectivo", "monto": 180000.0}]');
INSERT INTO ventas VALUES ('1196e595-6558-40e4-8162-def474cddc0e', NULL, 'Venta mostrador', 11500.0, 'ingreso', 0, '2026-11-14 13:15:00.000', '[{"medio": "efectivo", "monto": 11500.0}]');
INSERT INTO ventas VALUES ('40ebcaad-561a-4e0e-8c15-fcae251ed1b7', NULL, '4 × Arroz 500 g, 1 × Acetaminofén x10', 13000.0, 'ingreso', 0, '2026-11-14 16:00:00.000', '[{"medio": "efectivo", "monto": 5000.0}, {"medio": "nequi", "monto": 8000.0}]');
INSERT INTO ventas VALUES ('478a1238-5c92-4069-9754-6b5eaa7e8e55', NULL, 'Venta mostrador', 22000.0, 'ingreso', 0, '2026-11-14 16:15:00.000', '[{"medio": "tarjeta_debito", "monto": 22000.0}]');
INSERT INTO ventas VALUES ('67e69628-9609-415d-b9cb-ff973bcf869b', NULL, 'Venta mostrador', 32500.0, 'ingreso', 0, '2026-11-14 19:15:00.000', '[{"medio": "daviplata", "monto": 32500.0}]');
INSERT INTO ventas VALUES ('d317bbb6-a9ce-4e87-ad7e-4c069275d6bb', NULL, 'Venta mostrador', 11500.0, 'ingreso', 0, '2026-11-14 22:15:00.000', '[{"medio": "efectivo", "monto": 11500.0}]');
INSERT INTO ventas VALUES ('3f786c3b-9c7c-4ce2-862a-b93acefb1538', NULL, 'Venta mostrador', 18500.0, 'ingreso', 0, '2026-11-15 13:15:00.000', '[{"medio": "bancolombia", "monto": 18500.0}]');
INSERT INTO ventas VALUES ('eac49f60-6e5b-4a1a-ac0d-6b45dcaa16da', '25a674e6-01f4-4507-84e4-a09ca9dc936a', 'Abono', 20000.0, 'abono', 0, '2026-11-15 15:00:00.000', '[{"medio": "efectivo", "monto": 20000.0}]');
INSERT INTO ventas VALUES ('88195b57-505e-48ba-a562-0491da552945', NULL, '4 × Arroz 500 g, 1 × Acetaminofén x10', 13000.0, 'ingreso', 0, '2026-11-15 16:00:00.000', '[{"medio": "efectivo", "monto": 13000.0}]');
INSERT INTO ventas VALUES ('93335d9a-7c45-4c90-b284-10c1cc28a4da', NULL, 'Venta mostrador', 29000.0, 'ingreso', 0, '2026-11-15 16:15:00.000', '[{"medio": "efectivo", "monto": 29000.0}]');
INSERT INTO ventas VALUES ('c92c9e92-18d7-4b6f-aa47-7e1e43d61f1d', NULL, 'Venta mostrador', 8000.0, 'ingreso', 0, '2026-11-15 19:15:00.000', '[{"medio": "tarjeta_debito", "monto": 8000.0}]');
INSERT INTO ventas VALUES ('94f17921-0ab8-470f-9a91-df3be31c96c5', NULL, 'Venta mostrador', 18500.0, 'ingreso', 0, '2026-11-15 22:15:00.000', '[{"medio": "daviplata", "monto": 18500.0}]');
INSERT INTO ventas VALUES ('2437ca7b-73c3-46c6-b802-b5eae09d6ccb', NULL, 'Venta mostrador', 25500.0, 'ingreso', 0, '2026-11-16 13:15:00.000', '[{"medio": "efectivo", "monto": 25500.0}]');
INSERT INTO ventas VALUES ('a54ff3e9-e9b4-4425-877f-477cf155ed2d', NULL, '4 × Arroz 500 g, 1 × Acetaminofén x10', 13000.0, 'ingreso', 0, '2026-11-16 16:00:00.000', '[{"medio": "efectivo", "monto": 5000.0}, {"medio": "nequi", "monto": 8000.0}]');
INSERT INTO ventas VALUES ('cc436a62-18b0-4450-97c6-75882013b2c0', NULL, 'Venta mostrador', 36000.0, 'ingreso', 0, '2026-11-16 16:15:00.000', '[{"medio": "bancolombia", "monto": 36000.0}]');
INSERT INTO ventas VALUES ('94f5f587-e495-4fd3-93d7-d9b0bc761606', NULL, 'Venta mostrador', 15000.0, 'ingreso', 0, '2026-11-16 19:15:00.000', '[{"medio": "efectivo", "monto": 15000.0}]');
INSERT INTO ventas VALUES ('4881c4a7-055c-443d-9400-471588d340b8', NULL, 'Venta mostrador', 25500.0, 'ingreso', 0, '2026-11-16 22:15:00.000', '[{"medio": "tarjeta_debito", "monto": 25500.0}]');
INSERT INTO ventas VALUES ('9a1f10cb-9267-47de-bc4e-e582a901b7df', NULL, 'Venta mostrador', 32500.0, 'ingreso', 0, '2026-11-17 13:15:00.000', '[{"medio": "nequi", "monto": 32500.0}]');
INSERT INTO ventas VALUES ('3ce02e3f-098d-426f-a55e-0573c2ae02d7', NULL, '4 × Arroz 500 g, 1 × Acetaminofén x10', 13000.0, 'ingreso', 0, '2026-11-17 16:00:00.000', '[{"medio": "efectivo", "monto": 13000.0}]');
INSERT INTO ventas VALUES ('ccadcfde-b5a0-484d-a391-27ee48b46297', NULL, 'Venta mostrador', 11500.0, 'ingreso', 0, '2026-11-17 16:15:00.000', '[{"medio": "efectivo", "monto": 11500.0}]');
INSERT INTO ventas VALUES ('b4d3beef-2977-4880-9009-38ebba7688c7', NULL, 'Venta mostrador', 22000.0, 'ingreso', 0, '2026-11-17 19:15:00.000', '[{"medio": "bancolombia", "monto": 22000.0}]');
INSERT INTO ventas VALUES ('d958e181-4626-4477-991a-8163a59911ed', '9ef10ffc-918b-4a37-8689-d8088f0c2a3d', '0.75 × Queso campesino', 18000.0, 'ingreso', 1, '2026-11-17 21:00:00.000', NULL);
INSERT INTO ventas VALUES ('793f3404-407f-42ea-a188-b57a99cbddf7', NULL, 'Venta mostrador', 32500.0, 'ingreso', 0, '2026-11-17 22:15:00.000', '[{"medio": "efectivo", "monto": 32500.0}]');
INSERT INTO ventas VALUES ('05ef5be9-f15f-482a-9902-f5454da24c8e', NULL, 'Servicio de luz', 86000.0, 'egreso', 0, '2026-11-18 00:00:00.000', '[{"medio": "nequi", "monto": 86000.0}]');
INSERT INTO ventas VALUES ('509bbc0b-0e11-4f04-bcf1-c849d67d0629', NULL, 'Venta mostrador', 8000.0, 'ingreso', 0, '2026-11-18 12:07:00.000', '[{"medio": "bancolombia", "monto": 8000.0}]');
INSERT INTO ventas VALUES ('55c92295-5900-4daa-aee1-ce61a92c79d3', NULL, '1 × Sal mineralizada 25 kg', 48000.0, 'ingreso', 0, '2026-11-18 12:14:00.000', '[{"medio": "bancolombia", "monto": 48000.0}]');
INSERT INTO ventas VALUES ('d4465905-282a-42e4-a327-2272fb846546', NULL, 'Pago al preventista', 180000.0, 'egreso', 0, '2026-11-18 12:21:00.000', '[{"medio": "efectivo", "monto": 180000.0}]');
INSERT INTO ventas VALUES ('70b381cb-bec6-477a-835f-0b30a92e4892', NULL, 'Venta mostrador', 8000.0, 'ingreso', 0, '2026-11-18 13:15:00.000', '[{"medio": "efectivo", "monto": 8000.0}]');
INSERT INTO ventas VALUES ('6c1aef03-79ce-4ed4-9470-6a89f47b666d', NULL, '4 × Arroz 500 g, 1 × Acetaminofén x10', 13000.0, 'ingreso', 0, '2026-11-18 16:00:00.000', '[{"medio": "efectivo", "monto": 5000.0}, {"medio": "nequi", "monto": 8000.0}]');
INSERT INTO ventas VALUES ('ac428062-0e5d-4381-80c4-961790825d64', NULL, 'Venta mostrador', 18500.0, 'ingreso', 0, '2026-11-18 16:15:00.000', '[{"medio": "nequi", "monto": 18500.0}]');
INSERT INTO ventas VALUES ('704cda51-08c8-4135-860f-14f71df9481a', NULL, 'Venta mostrador', 29000.0, 'ingreso', 0, '2026-11-18 19:15:00.000', '[{"medio": "efectivo", "monto": 29000.0}]');
INSERT INTO inventario VALUES ('e636ed17-35a8-43b2-a8a8-7f3d043583a7', '62b0d57e-3013-459c-b2a5-fb3a16fd0160', 120.0, 'entrada', NULL, NULL, 1800.0, '2026-08-20 15:00:00.000');
INSERT INTO inventario VALUES ('18ba4ad9-65fd-4b47-be90-26b85ba4c193', '263f2814-91ab-4ba1-b99b-8884ee6f8efb', 40.0, 'entrada', NULL, NULL, 1900.0, '2026-08-20 15:00:00.000');
INSERT INTO inventario VALUES ('7633a78e-4987-4e3c-b904-7dc9a550020c', '2204d2f7-c28d-49c9-84d7-a0ab8bfbbc07', 6.0, 'entrada', NULL, NULL, 36000.0, '2026-08-20 15:00:00.000');
INSERT INTO inventario VALUES ('c64983d7-25a0-49f0-94ab-fe0a56259cf8', 'b48c623b-e6fd-4c03-9403-0b5dcd975a20', 8.0, 'entrada', NULL, NULL, 18000.0, '2026-08-20 15:00:00.000');
INSERT INTO inventario VALUES ('d893b60a-46a8-42ef-be16-ed30c156c2a7', '62b0d57e-3013-459c-b2a5-fb3a16fd0160', -4.0, 'venta', '465bb30e-a1fe-4173-b6fe-f23de8f2f4d1', 2500.0, 1800.0, '2026-11-05 16:00:00.000');
INSERT INTO inventario VALUES ('f4154491-ec37-4104-8ca7-5b04b64f88c6', '263f2814-91ab-4ba1-b99b-8884ee6f8efb', -1.0, 'venta', '465bb30e-a1fe-4173-b6fe-f23de8f2f4d1', 3000.0, 1900.0, '2026-11-05 16:00:00.000');
INSERT INTO inventario VALUES ('62c62fb5-f07f-4a97-8976-5b34a6cf3253', 'b48c623b-e6fd-4c03-9403-0b5dcd975a20', -0.75, 'venta', '5b65a595-946b-4b96-8951-86733b69493b', 24000.0, 18000.0, '2026-11-05 21:00:00.000');
INSERT INTO inventario VALUES ('705154cd-a1a9-4e40-9e37-d1284d458931', '62b0d57e-3013-459c-b2a5-fb3a16fd0160', 50.0, 'entrada', NULL, NULL, 1800.0, '2026-11-06 14:00:00.000');
INSERT INTO inventario VALUES ('4604f612-2c21-46a5-82d0-f7879bc611f9', '62b0d57e-3013-459c-b2a5-fb3a16fd0160', -4.0, 'venta', 'f12551f1-414e-4834-99a4-b85e7f305841', 2500.0, 1800.0, '2026-11-06 16:00:00.000');
INSERT INTO inventario VALUES ('f7303fc1-6cc7-4650-8108-de7ba66b65f5', '263f2814-91ab-4ba1-b99b-8884ee6f8efb', -1.0, 'venta', 'f12551f1-414e-4834-99a4-b85e7f305841', 3000.0, 1900.0, '2026-11-06 16:00:00.000');
INSERT INTO inventario VALUES ('a537380e-eb90-4cb2-a55c-3c49e1f859c0', '2204d2f7-c28d-49c9-84d7-a0ab8bfbbc07', -1.0, 'venta', '21b3233f-a32a-4019-a464-80d1ebe484d2', 48000.0, 36000.0, '2026-11-06 22:00:00.000');
INSERT INTO inventario VALUES ('ace941ff-8d78-49a6-b2a2-4f29484313fb', '62b0d57e-3013-459c-b2a5-fb3a16fd0160', -4.0, 'venta', 'c6bf9b4b-f1a8-47e8-baf3-160fa1014e39', 2500.0, 1800.0, '2026-11-07 16:00:00.000');
INSERT INTO inventario VALUES ('eca0e26b-b57a-41ad-b43f-d7c5e47239b8', '263f2814-91ab-4ba1-b99b-8884ee6f8efb', -1.0, 'venta', 'c6bf9b4b-f1a8-47e8-baf3-160fa1014e39', 3000.0, 1900.0, '2026-11-07 16:00:00.000');
INSERT INTO inventario VALUES ('e8681321-874c-43ae-a06d-fef7677e143f', '62b0d57e-3013-459c-b2a5-fb3a16fd0160', -4.0, 'venta', '15b5a50b-4880-4617-967f-2d5dc2e5562d', 2500.0, 1800.0, '2026-11-08 16:00:00.000');
INSERT INTO inventario VALUES ('586add43-f412-4aa9-a16e-1c3ea12e1329', '263f2814-91ab-4ba1-b99b-8884ee6f8efb', -1.0, 'venta', '15b5a50b-4880-4617-967f-2d5dc2e5562d', 3000.0, 1900.0, '2026-11-08 16:00:00.000');
INSERT INTO inventario VALUES ('02e14f21-47c0-4f93-8217-f99aa2c5a04f', '62b0d57e-3013-459c-b2a5-fb3a16fd0160', -4.0, 'venta', 'f895c140-aecd-4e96-b45b-11acaac28312', 2500.0, 1800.0, '2026-11-09 16:00:00.000');
INSERT INTO inventario VALUES ('ffce42e0-dc92-42bc-b944-b0609237a457', '263f2814-91ab-4ba1-b99b-8884ee6f8efb', -1.0, 'venta', 'f895c140-aecd-4e96-b45b-11acaac28312', 3000.0, 1900.0, '2026-11-09 16:00:00.000');
INSERT INTO inventario VALUES ('b5da7ac1-0d14-4818-a141-6f28139e6d26', 'b48c623b-e6fd-4c03-9403-0b5dcd975a20', -0.75, 'venta', '7b08ea59-52e5-4094-bfd4-0b72850da1b5', 24000.0, 18000.0, '2026-11-09 21:00:00.000');
INSERT INTO inventario VALUES ('40237706-f56d-49db-a4cd-aad7e634ee06', '62b0d57e-3013-459c-b2a5-fb3a16fd0160', -4.0, 'venta', '5207d9b4-b054-426b-8565-281e717a97b6', 2500.0, 1800.0, '2026-11-10 16:00:00.000');
INSERT INTO inventario VALUES ('e09819b8-a958-4835-a07e-5a61d5749439', '263f2814-91ab-4ba1-b99b-8884ee6f8efb', -1.0, 'venta', '5207d9b4-b054-426b-8565-281e717a97b6', 3000.0, 1900.0, '2026-11-10 16:00:00.000');
INSERT INTO inventario VALUES ('6dbbc5a1-308e-47bb-a10e-272f81cbf66c', '62b0d57e-3013-459c-b2a5-fb3a16fd0160', -4.0, 'venta', 'fbdb69ad-0e1a-4e82-875c-a2dc0289e2fd', 2500.0, 1800.0, '2026-11-11 16:00:00.000');
INSERT INTO inventario VALUES ('94f1caa8-87ed-47b9-b2e5-60b21579bf66', '263f2814-91ab-4ba1-b99b-8884ee6f8efb', -1.0, 'venta', 'fbdb69ad-0e1a-4e82-875c-a2dc0289e2fd', 3000.0, 1900.0, '2026-11-11 16:00:00.000');
INSERT INTO inventario VALUES ('379c1ec3-4de3-4701-a011-ace4f2078920', 'b48c623b-e6fd-4c03-9403-0b5dcd975a20', 6.0, 'entrada', NULL, NULL, 18000.0, '2026-11-12 13:00:00.000');
INSERT INTO inventario VALUES ('a565d556-5a4c-4fc2-94d8-07cdd2eb096e', '62b0d57e-3013-459c-b2a5-fb3a16fd0160', -4.0, 'venta', '08e38a88-d6b4-400b-9843-f1e87bcd63ff', 2500.0, 1800.0, '2026-11-12 16:00:00.000');
INSERT INTO inventario VALUES ('15ee793c-d98d-4e8a-87a8-a2be31d9581f', '263f2814-91ab-4ba1-b99b-8884ee6f8efb', -1.0, 'venta', '08e38a88-d6b4-400b-9843-f1e87bcd63ff', 3000.0, 1900.0, '2026-11-12 16:00:00.000');
INSERT INTO inventario VALUES ('adbebb19-fd6d-4576-bee9-d09c1eb72ae0', '2204d2f7-c28d-49c9-84d7-a0ab8bfbbc07', -1.0, 'venta', '806c4915-5846-4f52-8c20-d8fe9314abee', 48000.0, 36000.0, '2026-11-12 22:00:00.000');
INSERT INTO inventario VALUES ('4b228ceb-174a-4605-9612-56837e656ce6', '62b0d57e-3013-459c-b2a5-fb3a16fd0160', -4.0, 'venta', '7fada189-347e-4a41-a797-74c1a090b46a', 2500.0, 1800.0, '2026-11-13 16:00:00.000');
INSERT INTO inventario VALUES ('37762606-3060-40a3-97d9-a9bc9eb40267', '263f2814-91ab-4ba1-b99b-8884ee6f8efb', -1.0, 'venta', '7fada189-347e-4a41-a797-74c1a090b46a', 3000.0, 1900.0, '2026-11-13 16:00:00.000');
INSERT INTO inventario VALUES ('92506ee9-6687-4ccc-acb3-764401a1db03', 'b48c623b-e6fd-4c03-9403-0b5dcd975a20', -0.75, 'venta', 'b4cfd839-4e3e-4360-8d03-4ce255dd36c1', 24000.0, 18000.0, '2026-11-13 21:00:00.000');
INSERT INTO inventario VALUES ('aa71241f-a6aa-41a5-a636-39f01730d75f', '62b0d57e-3013-459c-b2a5-fb3a16fd0160', -4.0, 'venta', '40ebcaad-561a-4e0e-8c15-fcae251ed1b7', 2500.0, 1800.0, '2026-11-14 16:00:00.000');
INSERT INTO inventario VALUES ('c94b5141-55df-4f6e-abc3-a3f61e519c44', '263f2814-91ab-4ba1-b99b-8884ee6f8efb', -1.0, 'venta', '40ebcaad-561a-4e0e-8c15-fcae251ed1b7', 3000.0, 1900.0, '2026-11-14 16:00:00.000');
INSERT INTO inventario VALUES ('61e968cb-fb38-433d-aa2b-3d45885013a2', '62b0d57e-3013-459c-b2a5-fb3a16fd0160', -4.0, 'venta', '88195b57-505e-48ba-a562-0491da552945', 2500.0, 1800.0, '2026-11-15 16:00:00.000');
INSERT INTO inventario VALUES ('85984820-dd9c-4766-bca2-540980cda127', '263f2814-91ab-4ba1-b99b-8884ee6f8efb', -1.0, 'venta', '88195b57-505e-48ba-a562-0491da552945', 3000.0, 1900.0, '2026-11-15 16:00:00.000');
INSERT INTO inventario VALUES ('31bcd441-6095-4877-8ed1-f37322265de2', '62b0d57e-3013-459c-b2a5-fb3a16fd0160', -4.0, 'venta', 'a54ff3e9-e9b4-4425-877f-477cf155ed2d', 2500.0, 1800.0, '2026-11-16 16:00:00.000');
INSERT INTO inventario VALUES ('1c77f292-5cc6-4d3b-b7aa-8b18defb628c', '263f2814-91ab-4ba1-b99b-8884ee6f8efb', -1.0, 'venta', 'a54ff3e9-e9b4-4425-877f-477cf155ed2d', 3000.0, 1900.0, '2026-11-16 16:00:00.000');
INSERT INTO inventario VALUES ('7212c44e-2a34-478d-9f36-4544bcc01f56', '62b0d57e-3013-459c-b2a5-fb3a16fd0160', -4.0, 'venta', '3ce02e3f-098d-426f-a55e-0573c2ae02d7', 2500.0, 1800.0, '2026-11-17 16:00:00.000');
INSERT INTO inventario VALUES ('a1210ccd-be5f-43b5-9a34-3b20875b1515', '263f2814-91ab-4ba1-b99b-8884ee6f8efb', -1.0, 'venta', '3ce02e3f-098d-426f-a55e-0573c2ae02d7', 3000.0, 1900.0, '2026-11-17 16:00:00.000');
INSERT INTO inventario VALUES ('2233df2e-6546-4ecd-97d8-1c86f64145f8', 'b48c623b-e6fd-4c03-9403-0b5dcd975a20', -0.75, 'venta', 'd958e181-4626-4477-991a-8163a59911ed', 24000.0, 18000.0, '2026-11-17 21:00:00.000');
INSERT INTO inventario VALUES ('6590bb7e-2ece-428c-8b46-ad47def24528', '2204d2f7-c28d-49c9-84d7-a0ab8bfbbc07', -1.0, 'venta', '55c92295-5900-4daa-aee1-ce61a92c79d3', 48000.0, 36000.0, '2026-11-18 12:14:00.000');
INSERT INTO inventario VALUES ('6e86c751-3b2a-4e22-b46d-e2d0dec9cc88', '62b0d57e-3013-459c-b2a5-fb3a16fd0160', -4.0, 'venta', '6c1aef03-79ce-4ed4-9470-6a89f47b666d', 2500.0, 1800.0, '2026-11-18 16:00:00.000');
INSERT INTO inventario VALUES ('675d1ced-be00-4736-ba6d-d332704fae0e', '263f2814-91ab-4ba1-b99b-8884ee6f8efb', -1.0, 'venta', '6c1aef03-79ce-4ed4-9470-6a89f47b666d', 3000.0, 1900.0, '2026-11-18 16:00:00.000');

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
