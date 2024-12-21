BEGIN;

------------------------------------------------------------------------------
-- 0) Temizlik (opsiyonel): Eski tabloları ve fonksiyonları sil
------------------------------------------------------------------------------

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

-------------------------------------------------------------------------------
-- 1) Tablolar (15 adet) + Inheritance (uye, yonetici inherits kullanici)
-------------------------------------------------------------------------------

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

-------------------------------------------------------------------------------
-- 2) Fonksiyonlar (4 adet)
-------------------------------------------------------------------------------

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

-------------------------------------------------------------------------------
-- 3) Tetikleyiciler (4 adet)
-------------------------------------------------------------------------------

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

-------------------------------------------------------------------------------
-- 4) Örnek Veri 
-------------------------------------------------------------------------------

-- Yazar
INSERT INTO yazar (first_name, last_name) VALUES
('Antoine', 'Exupery'),
('Elif', 'Safak'),
('George', 'Orwell'),
('Jane', 'Austen');

-- Yayinevi
INSERT INTO yayinevi (name) VALUES
('Gallimard'),
('Can Yayincilik'),
('Penguin Books'),
('Modern Press');

-- Kategori
INSERT INTO kategori (name) VALUES
('Children Literature'),
('Roman'),
('Science Fiction'),
('Classic');

-- Kullanici (DO NOT INSERT INTO uye / yonetici, we do parent table)
INSERT INTO kullanici(first_name, last_name, email, password, role) VALUES
('Mehmet', 'Sensoy', 'mehmet@msn.com', '12345', 'uye'),
('Ayse', 'Demir', 'ayse@demir.com', 'aysepass', 'uye'),
('Ali', 'Kaya', 'ali@kaya.com', 'alipass', 'yonetici'),
('Zeynep', 'Cetin', 'zeynep@cetin.com', 'zeypass', 'yonetici');

-- Kitap
INSERT INTO kitap (title, summary, publish_date, author_id, publisher_id, category_id)
VALUES
('The Little Prince', 'A story of a prince from a tiny planet', '1943-04-06', 1, 1, 1),
('Hayvan Ciftligi', 'Animal Farm in Turkish version', '1945-08-17', 3, 2, 2),
('1984', 'Dystopian novel about totalitarian regime', '1949-06-08', 3, 3, 3),
('Pride and Prejudice', 'Romantic novel by Jane Austen', '1813-01-28', 4, 4, 4),
('Ciragan Baskini', 'Elif Safak story', '2010-02-20', 2, 2, 2);

-- Kitap Kulubu
INSERT INTO kitap_kulubu (name, description)
VALUES
('Okuma Kulubu', 'Monthly reading sessions'),
('Klasik Sevenler', 'We love classics'),
('Science Fiction Group', 'S-F fans gather here');

-- Kulup Uyeligini "kullanici" tablosundaki user_id'ye bagliyoruz
-- Mehmet= id=1, Ayse=2, Ali=3, Zeynep=4
INSERT INTO kulup_uyeligi (club_id, user_id) VALUES
(1, 1),  -- Mehmet -> Okuma Kulubu
(1, 2),  -- Ayse -> Okuma Kulubu
(2, 2),  -- Ayse -> Klasik Sevenler
(2, 3),  -- Ali -> Klasik Sevenler
(3, 4);  -- Zeynep -> Sci-Fi Group

-- Tartisma
INSERT INTO tartisma (club_id, topic, start_date)
VALUES
(1, 'Little Prince incelemesi', '2023-01-01'),
(2, 'Jane Austen romanlari', '2023-02-15'),
(3, 'Distopya ve 1984 tartismasi', '2023-03-10');

-- Yorum
INSERT INTO yorum (discussion_id, user_id, content)
VALUES
(1, 1, 'Ben cok begendim, cok akici.'),
(1, 2, 'Duygusal acidan cok etkileyici.'),
(2, 2, 'Pride and Prejudice favorim.'),
(2, 3, 'Jane Austen kalemi harika.'),
(3, 4, '1984 gercekten carpici.'),
(3, 1, 'Distopik kitaplardaki cagin onemi buyuk.');

-- Degerlendirme
INSERT INTO degerlendirme (book_id, user_id, rating, comment)
VALUES
(1, 1, 5, 'Muhtesem bir kitap'),
(1, 2, 4, 'Sevdim ama biraz daha uzun olabilirdi'),
(3, 4, 5, 'Okunmasi sart'),
(2, 1, 3, 'Ortalama bir roman'),
(5, 2, 4, 'Elif Safak kalemi fena degil');

-- Etkinlik
INSERT INTO etkinlik (club_id, event_name, event_date, description)
VALUES
(1, 'Aylik Kitap Toplantisi', '2023-05-20', 'Her ay Okuma Kulubu'),
(2, 'Klasik Roman Sohbeti', '2023-06-15', 'Jane Austen uzerine sunumlar'),
(3, 'Bilim Kurgu Gunu', '2023-07-10', 'Distopik evren tartismalari');

-- Etkinlik Katilimi
INSERT INTO etkinlik_katilimi (event_id, user_id)
VALUES
(1, 1),  -- Mehmet -> Aylik Kitap Toplantisi
(1, 2),  -- Ayse
(2, 2),  -- Ayse -> Klasik Roman Sohbeti
(3, 4);  -- Zeynep -> Bilim Kurgu Gunu

-- Mesaj
INSERT INTO mesaj (sender_id, receiver_id, content)
VALUES
(1, 3, 'Ali, bir sonraki kitap ne olsun?'),
(3, 1, 'Mehmet, bence 1984 devam edelim.'),
(2, 4, 'Zeynep, sunum icin ne gerekli?'),
(4, 2, 'Ayse, slaytlari mail atabilirsin.');

COMMIT;
