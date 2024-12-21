import psycopg2

DB_HOST = "localhost"
DB_NAME = "kitap_klubu"   # Veritabani adi
DB_USER = "postgres"
DB_PASSWORD = "54erkin54" # PostgreSQL sifren

def db_connect():
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )
        return conn
    except Exception as e:
        print("Error: Could not connect to the database.", e)
        return None

# 1) Add New User (calls yeni_kullanici_ekle function)
def add_new_user():
    first_name = input("First Name: ")
    last_name = input("Last Name: ")
    email = input("Email: ")
    password = input("Password: ")
    role = input("Role (uye/yonetici): ")

    conn = db_connect()
    if conn is None:
        return

    try:
        cursor = conn.cursor()
        # sakli yordam -> SELECT yeni_kullanici_ekle(...)
        cursor.execute("SELECT yeni_kullanici_ekle(%s, %s, %s, %s, %s)",
                       (first_name, last_name, email, password, role))
        conn.commit()
        print("New user added successfully.")
    except Exception as e:
        print("Error:", e)
    finally:
        cursor.close()
        conn.close()

# 2) Search Book (calls kitap_ara function)
def search_book():
    search_term = input("Enter book or author name to search: ")
    conn = db_connect()
    if conn is None:
        return

    try:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM kitap_ara(%s)", (search_term,))
        results = cursor.fetchall()
        print("Search Results:")
        if len(results) == 0:
            print("No book found with that term.")
        else:
            for row in results:
                print(f"Book ID: {row[0]}, Title: {row[1]}, Author: {row[2]} {row[3]}")
    except Exception as e:
        print("Error:", e)
    finally:
        cursor.close()
        conn.close()

# 3) Add New Book (calls kitap_ekle_function)
def add_new_book():
    title = input("Book Title: ")
    summary = input("Summary: ")
    publish_date = input("Publish Date (YYYY-MM-DD): ")
    author_id = int(input("Author ID: "))
    publisher_id = int(input("Publisher ID: "))
    category_id = int(input("Category ID: "))

    conn = db_connect()
    if conn is None:
        return

    try:
        cursor = conn.cursor()
        cursor.execute("SELECT kitap_ekle_function(%s, %s, %s, %s, %s, %s)",
                       (title, summary, publish_date, author_id, publisher_id, category_id))
        conn.commit()
        print("New book added successfully.")
    except Exception as e:
        print("Error:", e)
    finally:
        cursor.close()
        conn.close()

# 4) Add Club Membership (calls kulup_uyeligi_ekle)
def add_club_membership():
    club_id = int(input("Club ID: "))
    user_id = int(input("User ID: "))

    conn = db_connect()
    if conn is None:
        return

    try:
        cursor = conn.cursor()
        cursor.execute("SELECT kulup_uyeligi_ekle(%s, %s)", (club_id, user_id))
        conn.commit()
        print(f"User {user_id} added to club {club_id}.")
    except Exception as e:
        print("Error:", e)
    finally:
        cursor.close()
        conn.close()

# 5) Update User (direct SQL, no function)
def update_user():
    user_id = int(input("Enter the User ID to update: "))
    new_email = input("New Email: ")
    new_role = input("New Role (uye/yonetici): ")

    conn = db_connect()
    if conn is None:
        return

    try:
        cursor = conn.cursor()
        # direct SQL update
        cursor.execute("UPDATE kullanici SET email=%s, role=%s WHERE id=%s",
                       (new_email, new_role, user_id))
        rows_updated = cursor.rowcount
        conn.commit()

        if rows_updated > 0:
            print("User updated successfully.")
        else:
            print("No user found with that ID.")
    except Exception as e:
        print("Error:", e)
    finally:
        cursor.close()
        conn.close()

# 6) Delete User (direct SQL, triggers will handle cascade)
def delete_user():
    user_id = int(input("Enter the User ID to delete: "))
    conn = db_connect()
    if conn is None:
        return

    try:
        cursor = conn.cursor()
        # direct SQL delete
        cursor.execute("DELETE FROM kullanici WHERE id=%s", (user_id,))
        rows_deleted = cursor.rowcount
        conn.commit()

        if rows_deleted > 0:
            print("User deleted successfully.")
        else:
            print("No user found with that ID.")
    except Exception as e:
        print("Error:", e)
    finally:
        cursor.close()
        conn.close()

def main_menu():
    while True:
        print("\n--- Book Club Application ---")
        print("1. Add New User")
        print("2. Search Book")
        print("3. Add New Book")
        print("4. Add Club Membership")
        print("5. Update User")
        print("6. Delete User")
        print("7. Exit")
        choice = input("Please select an option: ")

        if choice == "1":
            add_new_user()
        elif choice == "2":
            search_book()
        elif choice == "3":
            add_new_book()
        elif choice == "4":
            add_club_membership()
        elif choice == "5":
            update_user()
        elif choice == "6":
            delete_user()
        elif choice == "7":
            print("Exiting the application. Goodbye!")
            break
        else:
            print("Invalid choice, please try again.")

if __name__ == "__main__":
    main_menu()
