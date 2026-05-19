import os
import shutil
import threading
from datetime import datetime
from pathlib import Path
import tkinter as tk
from tkinter import ttk, filedialog, messagebox
from tkinter.scrolledtext import ScrolledText

# Категорії файлів та їхні розширення
FILE_CATEGORIES = {
    "Відео": [".mp4", ".mov", ".avi", ".mkv", ".flv", ".wmv", ".webm", ".rsv", ".m4v", ".3gp"],
    "Зображення": [".jpg", ".jpeg", ".png", ".gif", ".bmp", ".tiff", ".webp", ".svg", ".heic", ".raw", ".psd"],
    "Документи": [".pdf", ".docx", ".doc", ".xlsx", ".xls", ".pptx", ".ppt", ".txt", ".csv", ".rtf", ".epub", ".pages", ".numbers", ".key"],
    "Аудіо": [".mp3", ".wav", ".aac", ".flac", ".ogg", ".m4a", ".wma", ".mid", ".midi"],
    "Архіви": [".zip", ".rar", ".tar", ".gz", ".7z", ".dmg", ".pkg", ".iso"],
}

# Словник для назв місяців українською
MONTHS_UA = {
    1: "Січень", 2: "Лютий", 3: "Березень", 4: "Квітень", 5: "Травень", 6: "Червень",
    7: "Липень", 8: "Серпень", 9: "Вересень", 10: "Жовтень", 11: "Листопад", 12: "Грудень"
}

class FileSorterApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Розумний сортувальник файлів")
        self.root.geometry("680x580")
        self.root.minimum_size = (680, 580)
        
        # Налаштування преміальної темної теми для уникнення проблем з macOS Dark Mode
        self.bg_color = "#1c1c1e"       # Системний темний колір macOS
        self.card_bg = "#2c2c2e"        # Колір карток / панелей
        self.entry_bg = "#3a3a3c"       # Колір полів введення
        self.accent_color = "#0a84ff"   # Apple Blue для темної теми
        self.text_color = "#ffffff"     # Білий текст
        self.secondary_text = "#aeaeb2" # Світло-сірий текст
        self.green_color = "#30d158"    # Apple Green для успіху
        
        self.root.configure(bg=self.bg_color)
        
        # Шляхи за замовчуванням
        self.default_dir = str(Path.home() / "Downloads")
        if not os.path.exists(self.default_dir):
            self.default_dir = str(Path.home())
            
        self.selected_path = tk.StringVar(value=self.default_dir)
        self.sort_mode = tk.StringVar(value="type")  # 'type' або 'date'
        
        # Створюємо змінні для прапорців категорій
        self.categories_vars = {}
        for cat in FILE_CATEGORIES.keys():
            self.categories_vars[cat] = tk.BooleanVar(value=True)
        self.categories_vars["Інші файли"] = tk.BooleanVar(value=True)
        
        self.create_widgets()
        
    def log(self, message):
        self.log_area.configure(state='normal')
        self.log_area.insert(tk.END, message + "\n")
        self.log_area.see(tk.END)
        self.log_area.configure(state='disabled')
        
    def clear_log(self):
        self.log_area.configure(state='normal')
        self.log_area.delete('1.0', tk.END)
        self.log_area.configure(state='disabled')

    def select_folder(self):
        folder = filedialog.askdirectory(initialdir=self.selected_path.get())
        if folder:
            self.selected_path.set(folder)
            self.log(f"[ІНФО] Вибрано папку: {folder}")

    def create_widgets(self):
        # Панель вибору папки
        path_frame = tk.Frame(self.root, bg=self.bg_color, padx=15, pady=10)
        path_frame.pack(fill="x")
        
        lbl_path = tk.Label(path_frame, text="Папка для сортування:", bg=self.bg_color, fg=self.text_color, font=("Helvetica", 11, "bold"))
        lbl_path.pack(anchor="w", pady=(0, 5))
        
        path_select_frame = tk.Frame(path_frame, bg=self.bg_color)
        path_select_frame.pack(fill="x")
        
        # Чорний/темний фон та білий текст для поля введення
        self.entry_path = tk.Entry(
            path_select_frame, 
            textvariable=self.selected_path, 
            font=("Helvetica", 11), 
            bg=self.entry_bg, 
            fg=self.text_color, 
            insertbackground=self.text_color,  # Колір курсору
            bd=1, 
            relief="solid",
            highlightthickness=0
        )
        self.entry_path.pack(side="left", fill="x", expand=True, ipady=6, padx=(0, 10))
        
        btn_browse = tk.Button(
            path_select_frame, 
            text="Огляд...", 
            command=self.select_folder, 
            bg=self.card_bg, 
            fg=self.accent_color, 
            activebackground=self.entry_bg,
            activeforeground=self.accent_color,
            relief="flat", 
            highlightbackground=self.bg_color, 
            font=("Helvetica", 11, "bold"),
            padx=10,
            pady=4
        )
        btn_browse.pack(side="right")

        # Основна панель налаштувань (картка)
        settings_frame = tk.LabelFrame(
            self.root, 
            text=" Налаштування сортування ", 
            bg=self.card_bg, 
            fg=self.text_color, 
            font=("Helvetica", 11, "bold"), 
            bd=1, 
            relief="solid", 
            padx=15, 
            pady=15
        )
        settings_frame.pack(fill="x", padx=15, pady=10)
        
        # Режим сортування
        mode_frame = tk.Frame(settings_frame, bg=self.card_bg)
        mode_frame.pack(fill="x", pady=(0, 10))
        
        lbl_mode = tk.Label(mode_frame, text="Режим групування:", bg=self.card_bg, fg=self.text_color, font=("Helvetica", 11, "bold"))
        lbl_mode.pack(side="left", padx=(0, 20))
        
        # Радіокнопки з явними кольорами темної теми
        rb_type = tk.Radiobutton(
            mode_frame, 
            text="За типами файлів", 
            variable=self.sort_mode, 
            value="type", 
            bg=self.card_bg, 
            fg=self.text_color, 
            selectcolor=self.card_bg,  # Запобігає білим цяткам на темному тлі
            activebackground=self.card_bg, 
            activeforeground=self.text_color,
            font=("Helvetica", 11)
        )
        rb_type.pack(side="left", padx=10)
        
        rb_date = tk.Radiobutton(
            mode_frame, 
            text="За датами (Місяць/Рік)", 
            variable=self.sort_mode, 
            value="date", 
            bg=self.card_bg, 
            fg=self.text_color, 
            selectcolor=self.card_bg,
            activebackground=self.card_bg, 
            activeforeground=self.text_color,
            font=("Helvetica", 11)
        )
        rb_date.pack(side="left", padx=10)
        
        # Лінія розділення
        separator = tk.Frame(settings_frame, height=1, bg="#48484a")
        separator.pack(fill="x", pady=10)
        
        # Вибір категорій (чекбокси)
        cat_lbl = tk.Label(settings_frame, text="Які файли сортувати:", bg=self.card_bg, fg=self.text_color, font=("Helvetica", 11, "bold"))
        cat_lbl.pack(anchor="w", pady=(0, 5))
        
        checkboxes_frame = tk.Frame(settings_frame, bg=self.card_bg)
        checkboxes_frame.pack(fill="x")
        
        # Чекбокси з явними кольорами для темної теми
        col = 0
        row = 0
        for cat, var in self.categories_vars.items():
            cb = tk.Checkbutton(
                checkboxes_frame, 
                text=cat, 
                variable=var, 
                bg=self.card_bg, 
                fg=self.text_color, 
                selectcolor=self.card_bg,
                activebackground=self.card_bg, 
                activeforeground=self.text_color,
                font=("Helvetica", 11)
            )
            cb.grid(row=row, column=col, sticky="w", padx=15, pady=5)
            col += 1
            if col > 2:
                col = 0
                row += 1

        # Кнопки дії
        buttons_frame = tk.Frame(self.root, bg=self.bg_color, padx=15, pady=10)
        buttons_frame.pack(fill="x")
        
        btn_preview = tk.Button(
            buttons_frame, 
            text="Попередній перегляд (Без змін)", 
            command=self.start_preview, 
            bg=self.card_bg, 
            fg=self.text_color, 
            activebackground=self.entry_bg,
            activeforeground=self.text_color,
            relief="groove", 
            highlightbackground=self.bg_color,
            font=("Helvetica", 11, "bold"), 
            padx=10, 
            pady=8
        )
        btn_preview.pack(side="left", expand=True, fill="x", padx=(0, 10))
        
        btn_sort = tk.Button(
            buttons_frame, 
            text="Почати сортування", 
            command=self.start_sorting, 
            bg=self.accent_color, 
            fg="white", 
            activebackground="#0056b3", 
            relief="flat", 
            highlightbackground=self.bg_color,
            font=("Helvetica", 11, "bold"), 
            padx=10, 
            pady=8
        )
        btn_sort.pack(side="right", expand=True, fill="x")

        # Панель логів
        log_frame = tk.Frame(self.root, bg=self.bg_color, padx=15, pady=10)
        log_frame.pack(fill="both", expand=True)
        
        log_header = tk.Frame(log_frame, bg=self.bg_color)
        log_header.pack(fill="x", pady=(0, 5))
        
        lbl_log = tk.Label(log_header, text="Журнал виконання:", bg=self.bg_color, fg=self.text_color, font=("Helvetica", 11, "bold"))
        lbl_log.pack(side="left")
        
        btn_clear = tk.Button(
            log_header, 
            text="Очистити", 
            command=self.clear_log, 
            bg=self.bg_color, 
            fg=self.secondary_text, 
            activebackground=self.bg_color,
            activeforeground=self.text_color,
            relief="flat", 
            font=("Helvetica", 10)
        )
        btn_clear.pack(side="right")
        
        # Вікно логування з темно-чорним тлом і яскравим текстом
        self.log_area = ScrolledText(
            log_frame, 
            height=10, 
            bg="#151515", 
            fg="#e5e5e7", 
            insertbackground="#ffffff", 
            font=("Courier", 11), 
            bd=1, 
            relief="solid",
            highlightthickness=0
        )
        self.log_area.pack(fill="both", expand=True)
        self.log_area.configure(state='disabled')
        
        # Вітальне повідомлення
        self.log("=== Розумний сортувальник файлів ===")
        self.log("1. Виберіть потрібну папку вище.")
        self.log("2. Натисніть 'Попередній перегляд', щоб перевірити, які файли буде знайдено.")
        self.log("3. Натисніть 'Почати сортування' для автоматичного розкладання файлів.")

    def get_destination_folder(self, file_path, target_dir):
        ext = file_path.suffix.lower()
        
        # Якщо режим сортування за типом
        if self.sort_mode.get() == "type":
            dest_cat = "Інші файли"
            for cat, extensions in FILE_CATEGORIES.items():
                if ext in extensions:
                    dest_cat = cat
                    break
            
            # Перевіряємо, чи користувач хоче сортувати цей тип
            if not self.categories_vars[dest_cat].get():
                return None
                
            return Path(target_dir) / dest_cat
            
        # Якщо режим сортування за датою
        elif self.sort_mode.get() == "date":
            # Визначаємо категорію, щоб перевірити фільтр
            dest_cat = "Інші файли"
            for cat, extensions in FILE_CATEGORIES.items():
                if ext in extensions:
                    dest_cat = cat
                    break
                    
            if not self.categories_vars[dest_cat].get():
                return None
                
            # Отримуємо дату створення / модифікації файлу
            stat = file_path.stat()
            # На macOS ctime - це час зміни метаданих, mtime - час модифікації.
            # Використовуємо mtime, як надійніший показник дати файлу
            file_time = datetime.fromtimestamp(stat.st_mtime)
            year = str(file_time.year)
            month_num = file_time.month
            month_name = MONTHS_UA[month_num]
            
            # Назва папки виду "2026/2026-05_Травень"
            folder_name = f"{year}-{month_num:02d}_{month_name}"
            return Path(target_dir) / year / folder_name

    def unique_dest_path(self, dest_folder, file_name):
        base = file_name.stem
        ext = file_name.suffix
        counter = 1
        new_name = file_name.name
        
        while (dest_folder / new_name).exists():
            new_name = f"{base} ({counter}){ext}"
            counter += 1
            
        return dest_folder / new_name

    def process_sorting(self, dry_run=True):
        target_dir = self.selected_path.get()
        
        if not target_dir or not os.path.exists(target_dir):
            messagebox.showerror("Помилка", "Вказана папка не існує!")
            return
            
        target_path = Path(target_dir)
        
        action_word = "Попередній перегляд" if dry_run else "Сортування"
        self.log(f"\n--- Початок процесу: {action_word} ---")
        
        # Шукаємо файли безпосередньо в цій папці (не заходячи в підпапки, які ми самі створимо)
        files_to_sort = []
        try:
            for item in target_path.iterdir():
                if item.is_file() and not item.name.startswith('.'):
                    files_to_sort.append(item)
        except Exception as e:
            self.log(f"[ПОМИЛКА] Не вдалося отримати доступ до папки: {e}")
            return
            
        if not files_to_sort:
            self.log("У цій папці немає файлів для сортування.")
            self.log("--- Процес завершено ---")
            return
            
        moved_count = 0
        ignored_count = 0
        
        for file_path in files_to_sort:
            dest_folder = self.get_destination_folder(file_path, target_path)
            
            if dest_folder is None:
                ignored_count += 1
                continue
                
            # Не переміщуємо файл сам у себе, якщо він вже лежить у правильній папці
            if file_path.parent == dest_folder:
                continue
                
            dest_file_path = self.unique_dest_path(dest_folder, file_path)
            
            # Відображення відносних шляхів для зручності
            rel_source = file_path.name
            rel_dest = dest_file_path.relative_to(target_path)
            
            if dry_run:
                self.log(f"[ПЛАНУЄТЬСЯ] '{rel_source}' -> папку '{rel_dest.parent}'")
            else:
                try:
                    # Створюємо папку призначення, якщо її немає
                    dest_folder.mkdir(parents=True, exist_ok=True)
                    # Переміщуємо файл
                    shutil.move(str(file_path), str(dest_file_path))
                    self.log(f"[УСПІШНО] '{rel_source}' -> '{rel_dest}'")
                except Exception as e:
                    self.log(f"[ПОМИЛКА] Не вдалося перемістити '{rel_source}': {e}")
                    
            moved_count += 1
            
        self.log(f"\n--- {action_word} завершено ---")
        if dry_run:
            self.log(f"Буде впорядковано файлів: {moved_count}")
            self.log(f"Проігноровано файлів (вимкнені у фільтрах): {ignored_count}")
            self.log("Жодних змін на диску не було проведено.")
        else:
            self.log(f"Успішно впорядковано файлів: {moved_count}")
            self.log(f"Проігноровано файлів: {ignored_count}")
            messagebox.showinfo("Готово", f"Сортування завершено!\nВпорядковано файлів: {moved_count}")

    def start_preview(self):
        # Запускаємо в окремому потоці, щоб інтерфейс не зависав
        threading.Thread(target=self.process_sorting, args=(True,), daemon=True).start()

    def start_sorting(self):
        if messagebox.askyesno("Підтвердження", "Ви впевнені, що хочете почати сортування файлів?"):
            threading.Thread(target=self.process_sorting, args=(False,), daemon=True).start()

if __name__ == "__main__":
    root = tk.Tk()
    app = FileSorterApp(root)
    root.mainloop()
