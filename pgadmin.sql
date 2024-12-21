--------------------------------------------------------------------------------
-- Temizlik (opsiyonel): Mevcut tabloları sil
--------------------------------------------------------------------------------
DROP TABLE IF EXISTS mesaj CASCADE;
DROP TABLE IF EXISTS etkinlik_katilimi CASCADE;
DROP TABLE IF EXISTS etkinlik CASCADE;
DROP TABLE IF EXISTS degerlendirme CASCADE;
DROP TABLE IF EXISTS yorum CASCADE;
DROP TABLE IF EXISTS tartisma CASCADE;
DROP TABLE IF EXISTS kulup_uyeligi CASCADE;
DROP TABLE IF EXISTS kitap_kulubu CASCADE;
DROP TABLE IF EXISTS kitap CASCADE;
DROP TABLE IF EXISTS kategori CASCADE;
DROP TABLE IF EXISTS yayinevi CASCADE;
DROP TABLE IF EXISTS yazar CASCADE;
DROP TABLE IF EXISTS yonetici CASCADE;
DROP TABLE IF EXISTS uye CASCADE;
DROP TABLE IF EXISTS kullanici CASCADE;

DROP FUNCTION IF EXISTS yeni_kullanici_ekle(varchar, varchar, varchar, varchar, varchar);
DROP FUNCTION IF EXISTS kitap_ekle_function(varchar, text, date, int, int, int);
DROP FUNCTION IF EXISTS kulup_uyeligi_ekle(int, int);
DROP FUNCTION IF EXISTS kitap_ara(varchar);
DROP FUNCTION IF EXISTS yorum_eklendiginde_bildirim() CASCADE;
DROP FUNCTION IF EXISTS ortalama_puan_guncelle() CASCADE;
DROP FUNCTION IF EXISTS mesaj_tarihi_otomatik() CASCADE;
DROP FUNCTION IF EXISTS kullanici_silince_temizle() CASCADE;

--------------------------------------------------------------------------------
-- 1) Tablolar (15 adet) ve Inheritance
--------------------------------------------------------------------------------

CREATE TABLE kullanici (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100) UNIQUE,
    password VARCHAR(100),
    role VARCHAR(20) -- 'uye' veya 'yonetici'
);

CREATE TABLE uye (
    CHECK (role = 'uye')
) INHERITS (kullanici);

CREATE TABLE yonetici (
    CHECK (role = 'yonetici')
) INHERITS (kullanici);

CREATE TABLE yazar (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50)
);

CREATE TABLE yayinevi (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100)
);

CREATE TABLE kategori (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50)
);

CREATE TABLE kitap (
    id SERIAL PRIMARY KEY,
    title VARCHAR(200),
    summary TEXT,
    publish_date DATE,
    author_id INT REFERENCES yazar(id) ON DELETE CASCADE,
    publisher_id INT REFERENCES yayinevi(id) ON DELETE CASCADE,
    category_id INT REFERENCES kategori(id) ON DELETE CASCADE,
    average_rating NUMERIC(3,2) DEFAULT 0
);

CREATE TABLE kitap_kulubu (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    description TEXT
);

CREATE TABLE kulup_uyeligi (
    id SERIAL PRIMARY KEY,
    club_id INT REFERENCES kitap_kulubu(id) ON DELETE CASCADE,
    user_id INT REFERENCES kullanici(id) ON DELETE CASCADE
);

CREATE TABLE tartisma (
    id SERIAL PRIMARY KEY,
    club_id INT REFERENCES kitap_kulubu(id) ON DELETE CASCADE,
    topic VARCHAR(255),
    start_date DATE DEFAULT CURRENT_DATE
);

CREATE TABLE yorum (
    id SERIAL PRIMARY KEY,
    discussion_id INT REFERENCES tartisma(id) ON DELETE CASCADE,
    user_id INT REFERENCES kullanici(id) ON DELETE CASCADE,
    content TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE degerlendirme (
    id SERIAL PRIMARY KEY,
    book_id INT REFERENCES kitap(id) ON DELETE CASCADE,
    user_id INT REFERENCES kullanici(id) ON DELETE CASCADE,
    rating INT CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE etkinlik (
    id SERIAL PRIMARY KEY,
    club_id INT REFERENCES kitap_kulubu(id) ON DELETE CASCADE,
    event_name VARCHAR(100),
    event_date DATE,
    description TEXT
);

CREATE TABLE etkinlik_katilimi (
    id SERIAL PRIMARY KEY,
    event_id INT REFERENCES etkinlik(id) ON DELETE CASCADE,
    user_id INT REFERENCES kullanici(id) ON DELETE CASCADE
);

CREATE TABLE mesaj (
    id SERIAL PRIMARY KEY,
    sender_id INT REFERENCES kullanici(id) ON DELETE CASCADE,
    receiver_id INT REFERENCES kullanici(id) ON DELETE CASCADE,
    content TEXT,
    sent_at TIMESTAMP
);

--------------------------------------------------------------------------------
-- 2) Fonksiyonlar (4 adet)
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION yeni_kullanici_ekle(
    p_first_name VARCHAR,
    p_last_name VARCHAR,
    p_email VARCHAR,
    p_password VARCHAR,
    p_role VARCHAR
)
RETURNS void AS $$
BEGIN
    INSERT INTO kullanici(first_name, last_name, email, password, role)
    VALUES (p_first_name, p_last_name, p_email, p_password, p_role);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION kitap_ekle_function(
    p_title VARCHAR,
    p_summary TEXT,
    p_publish_date DATE,
    p_author_id INT,
    p_publisher_id INT,
    p_category_id INT
)
RETURNS void AS $$
BEGIN
    INSERT INTO kitap (title, summary, publish_date, author_id, publisher_id, category_id)
    VALUES (p_title, p_summary, p_publish_date, p_author_id, p_publisher_id, p_category_id);
END; 
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION kulup_uyeligi_ekle(
    p_club_id INT,
    p_user_id INT
)
RETURNS void AS $$
BEGIN
    INSERT INTO kulup_uyeligi (club_id, user_id)
    VALUES (p_club_id, p_user_id);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION kitap_ara(p_search_term VARCHAR)
RETURNS TABLE (
    kitap_id INT,
    kitap_title VARCHAR,
    yazar_adi VARCHAR,
    yazar_soyadi VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT k.id, k.title, y.first_name, y.last_name
    FROM kitap k
    JOIN yazar y ON k.author_id = y.id
    WHERE k.title ILIKE '%' || p_search_term || '%'
       OR y.first_name ILIKE '%' || p_search_term || '%'
       OR y.last_name ILIKE '%' || p_search_term || '%';
END;
$$;

--------------------------------------------------------------------------------
-- 3) Tetikleyiciler (4 adet)
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION yorum_eklendiginde_bildirim() 
RETURNS TRIGGER AS $$
BEGIN
    RAISE NOTICE 'Yeni yorum eklendi. Yorum ID: %, Kullanici ID: %', NEW.id, NEW.user_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_yorum_eklendi_bildirim
AFTER INSERT ON yorum
FOR EACH ROW
EXECUTE PROCEDURE yorum_eklendiginde_bildirim();

CREATE OR REPLACE FUNCTION ortalama_puan_guncelle() 
RETURNS TRIGGER AS $$
BEGIN
    UPDATE kitap
    SET average_rating = (
        SELECT AVG(rating)::NUMERIC(3,2)
        FROM degerlendirme
        WHERE book_id = NEW.book_id
    )
    WHERE id = NEW.book_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ortalama_puan_guncelle
AFTER INSERT OR UPDATE ON degerlendirme
FOR EACH ROW
EXECUTE PROCEDURE ortalama_puan_guncelle();

CREATE OR REPLACE FUNCTION mesaj_tarihi_otomatik() 
RETURNS TRIGGER AS $$
BEGIN
    NEW.sent_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_mesaj_tarihi_otomatik
BEFORE INSERT ON mesaj
FOR EACH ROW
EXECUTE PROCEDURE mesaj_tarihi_otomatik();

CREATE OR REPLACE FUNCTION kullanici_silince_temizle()
RETURNS TRIGGER AS $$
BEGIN
    RAISE NOTICE 'Kullanici silindi. ID: %', OLD.id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_kullanici_silince_temizle
BEFORE DELETE ON kullanici
FOR EACH ROW
EXECUTE PROCEDURE kullanici_silince_temizle();

--------------------------------------------------------------------------------
-- 4) Örnek Veri Ekleyelim (Opsiyonel)
--------------------------------------------------------------------------------

-- Yazar, Yayınevi, Kategori ekleme
INSERT INTO yazar(first_name, last_name) VALUES ('Antoine', 'Exupery'), ('Elif', 'Safak');
INSERT INTO yayinevi(name) VALUES ('Gallimard'), ('Can Yayincilik');
INSERT INTO kategori(name) VALUES('Children Literature'), ('Roman');

-- Bir adet kulüp ekleyelim
INSERT INTO kitap_kulubu(name, description) VALUES('Okuma Kulübü', 'Her ay yeni kitap incelemesi');

COMMIT;
