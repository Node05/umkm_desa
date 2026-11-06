-- 1. Buat Tipe Data ENUM
CREATE TYPE user_role AS ENUM ('admin', 'penjual', 'pembeli');
CREATE TYPE umkm_status AS ENUM ('pending', 'active', 'rejected');
CREATE TYPE product_availability AS ENUM ('available', 'unavailable');
CREATE TYPE content_status AS ENUM ('pending', 'approved', 'rejected');
CREATE TYPE contact_platform AS ENUM ('whatsapp', 'instagram', 'facebook');
CREATE TYPE interaction_type AS ENUM (
    'view_profile', 'view_product', 'click_whatsapp',
    'click_instagram', 'click_facebook', 'click_maps'
);

-- 2. Tabel users
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    email VARCHAR(255) NOT NULL,
    password_hash TEXT NOT NULL,
    role user_role NOT NULL DEFAULT 'pembeli',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX uq_users_email_lower ON users (LOWER(email));

-- 3. Tabel umkm
CREATE TABLE umkm (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(160) NOT NULL,
    slug VARCHAR(180) NOT NULL UNIQUE,
    description TEXT,
    address TEXT NOT NULL,
    village VARCHAR(120) NOT NULL,
    district VARCHAR(120),
    latitude NUMERIC(10,7) CHECK (latitude BETWEEN -90 AND 90),
    longitude NUMERIC(10,7) CHECK (longitude BETWEEN -180 AND 180),
    logo_path TEXT,
    status umkm_status NOT NULL DEFAULT 'pending',
    verified_by BIGINT REFERENCES users(id) ON DELETE RESTRICT,
    verified_at TIMESTAMPTZ,
    rejection_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (status = 'active' OR (verified_by IS NOT NULL AND verified_at IS NOT NULL))
);
CREATE INDEX idx_umkm_status ON umkm(status);
CREATE INDEX idx_umkm_village ON umkm(village);

-- 4. Tabel categories
CREATE TABLE categories (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    slug VARCHAR(120) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 5. Tabel products
CREATE TABLE products (
    id BIGSERIAL PRIMARY KEY,
    umkm_id BIGINT NOT NULL REFERENCES umkm(id) ON DELETE CASCADE,
    category_id BIGINT NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
    name VARCHAR(160) NOT NULL,
    slug VARCHAR(180) NOT NULL,
    description TEXT,
    price NUMERIC(14,2) NOT NULL CHECK (price >= 0),
    unit VARCHAR(40),
    availability product_availability NOT NULL DEFAULT 'available',
    moderation_status content_status NOT NULL DEFAULT 'pending',
    moderated_by BIGINT REFERENCES users(id) ON DELETE RESTRICT,
    moderated_at TIMESTAMPTZ,
    rejection_reason TEXT,
    is_featured BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (umkm_id, slug),
    CHECK (
        (moderation_status = 'pending' AND moderated_by IS NULL AND moderated_at IS NULL)
        OR
        (moderation_status IN ('approved', 'rejected') AND moderated_by IS NOT NULL AND moderated_at IS NOT NULL)
    )
);
CREATE INDEX idx_products_umkm ON products(umkm_id);
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_availability ON products(availability);
CREATE INDEX idx_products_moderation ON products(moderation_status);

-- 6. Tabel product_images
CREATE TABLE product_images (
    id BIGSERIAL PRIMARY KEY,
    product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    image_path TEXT NOT NULL,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_product_images_product ON product_images(product_id);
CREATE UNIQUE INDEX uq_product_one_primary_image ON product_images(product_id) WHERE is_primary = TRUE;

-- 7. Tabel umkm_contacts
CREATE TABLE umkm_contacts (
    id BIGSERIAL PRIMARY KEY,
    umkm_id BIGINT NOT NULL REFERENCES umkm(id) ON DELETE CASCADE,
    platform contact_platform NOT NULL,
    contact_value VARCHAR(255) NOT NULL,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    verified_by BIGINT REFERENCES users(id) ON DELETE RESTRICT,
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (umkm_id, platform, contact_value),
    CHECK (
        (is_verified = FALSE AND verified_by IS NULL AND verified_at IS NULL)
        OR
        (is_verified = TRUE AND verified_by IS NOT NULL AND verified_at IS NOT NULL)
    )
);
CREATE INDEX idx_umkm_contacts_umkm ON umkm_contacts(umkm_id);
CREATE UNIQUE INDEX uq_umkm_primary_contact_per_platform ON umkm_contacts(umkm_id, platform) WHERE is_primary = TRUE;

-- 8. Tabel umkm_operating_hours
CREATE TABLE umkm_operating_hours (
    id BIGSERIAL PRIMARY KEY,
    umkm_id BIGINT NOT NULL REFERENCES umkm(id) ON DELETE CASCADE,
    day_of_week SMALLINT NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
    open_time TIME,
    close_time TIME,
    is_closed BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE (umkm_id, day_of_week),
    CHECK (
        (is_closed = TRUE AND open_time IS NULL AND close_time IS NULL)
        OR
        (is_closed = FALSE AND open_time IS NOT NULL AND close_time IS NOT NULL AND open_time < close_time)
    )
);

-- 9. Tabel umkm_announcements
CREATE TABLE umkm_announcements (
    id BIGSERIAL PRIMARY KEY,
    umkm_id BIGINT NOT NULL REFERENCES umkm(id) ON DELETE CASCADE,
    title VARCHAR(160) NOT NULL,
    content TEXT NOT NULL,
    image_path TEXT,
    moderation_status content_status NOT NULL DEFAULT 'pending',
    moderated_by BIGINT REFERENCES users(id) ON DELETE RESTRICT,
    moderated_at TIMESTAMPTZ,
    rejection_reason TEXT,
    start_date DATE,
    end_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (end_date IS NULL OR start_date IS NULL OR end_date > start_date),
    CHECK (
        (moderation_status = 'pending' AND moderated_by IS NULL AND moderated_at IS NULL)
        OR
        (moderation_status IN ('approved', 'rejected') AND moderated_by IS NOT NULL AND moderated_at IS NOT NULL)
    )
);
CREATE INDEX idx_announcements_umkm ON umkm_announcements(umkm_id);
CREATE INDEX idx_announcements_status ON umkm_announcements(moderation_status);

-- 10. Tabel admin_activity_logs
CREATE TABLE admin_activity_logs (
    id BIGSERIAL PRIMARY KEY,
    admin_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(80) NOT NULL,
    entity_id BIGINT,
    description TEXT,
    old_values JSONB,
    new_values JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_admin_logs_admin ON admin_activity_logs(admin_id);
CREATE INDEX idx_admin_logs_entity ON admin_activity_logs(entity_type, entity_id);
CREATE INDEX idx_admin_logs_created ON admin_activity_logs(created_at);

-- 11. Tabel system_settings
CREATE TABLE system_settings (
    id BIGSERIAL PRIMARY KEY,
    setting_key VARCHAR(120) NOT NULL UNIQUE,
    setting_value TEXT,
    description TEXT,
    updated_by BIGINT REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 12. Tabel data_export_logs
CREATE TABLE data_export_logs (
    id BIGSERIAL PRIMARY KEY,
    exported_by BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    export_name VARCHAR(160) NOT NULL,
    data_type VARCHAR(100) NOT NULL,
    file_format VARCHAR(10) NOT NULL CHECK (file_format IN ('csv', 'xlsx', 'pdf')),
    file_path TEXT,
    filters JSONB,
    exported_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_export_logs_admin ON data_export_logs(exported_by);
CREATE INDEX idx_export_logs_date ON data_export_logs(exported_at);

-- 13. Tabel umkm_interactions
CREATE TABLE umkm_interactions (
    id BIGSERIAL PRIMARY KEY,
    umkm_id BIGINT NOT NULL REFERENCES umkm(id) ON DELETE CASCADE,
    product_id BIGINT REFERENCES products(id) ON DELETE SET NULL,
    interaction_type interaction_type NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (interaction_type != 'view_product' OR product_id IS NOT NULL)
);
CREATE INDEX idx_interactions_umkm_date ON umkm_interactions(umkm_id, created_at);
CREATE INDEX idx_interactions_product ON umkm_interactions(product_id);
CREATE INDEX idx_interactions_type_date ON umkm_interactions(interaction_type, created_at);