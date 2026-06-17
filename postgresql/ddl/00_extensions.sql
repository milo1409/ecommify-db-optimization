-- 00_extensions.sql
-- Extensiones PostgreSQL requeridas para Ecommify.
-- Ejecutar primero en Supabase SQL Editor.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Encriptación y generación segura de hashes / UUID.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Generación de UUID.
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Búsquedas textuales avanzadas.
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Geolocalización.
CREATE EXTENSION IF NOT EXISTS postgis;

-- pg_partman puede no estar disponible en Supabase Free Tier.
-- Se intenta crear sin romper la ejecución si no está habilitada.
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS pg_partman;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'pg_partman no está disponible en este entorno. Se usará particionamiento declarativo nativo.';
END $$;