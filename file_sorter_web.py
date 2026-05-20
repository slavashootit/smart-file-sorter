import os
import shutil
import webview
import hashlib
import json
from datetime import datetime
from pathlib import Path

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

class Api:
    def __init__(self):
        self._window = None
        self.history_file = Path(__file__).parent / "last_session.json"

    def set_window(self, window):
        self._window = window

    def get_default_folder(self):
        default_dir = Path.home() / "Downloads"
        if not default_dir.exists():
            default_dir = Path.home()
        return str(default_dir)

    def select_folder(self):
        if not self._window:
            return ""
        # Виклик нативного вікна вибору папки macOS
        result = self._window.create_file_dialog(webview.FOLDER_DIALOG)
        if result and len(result) > 0:
            return result[0]
        return ""

    def check_history_exists(self):
        # Перевірка наявності історії сортування для кнопки скасування (Undo)
        try:
            if self.history_file.exists() and self.history_file.stat().st_size > 0:
                with open(self.history_file, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    return bool(data.get("moves"))
        except Exception:
            pass
        return False

    def get_file_md5(self, file_path):
        # Швидке обчислення MD5-хешу файлу для перевірки на дублікати
        hash_md5 = hashlib.md5()
        try:
            with open(file_path, "rb") as f:
                for chunk in iter(lambda: f.read(65536), b""):
                    hash_md5.update(chunk)
            return hash_md5.hexdigest()
        except Exception:
            try:
                stat = file_path.stat()
                return f"{stat.st_size}_{stat.st_mtime}"
            except Exception:
                return str(file_path)

    def undo_sorting(self):
        logs = []
        logs.append("--- Запуск скасування останнього сортування ---")
        
        if not self.history_file.exists():
            return {"error": "Немає збереженої історії для скасування!", "has_history": False}
            
        try:
            with open(self.history_file, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception as e:
            return {"error": f"Не вдалося зчитати файл історії: {e}", "has_history": False}
            
        moves = data.get("moves", [])
        created_dirs = data.get("created_dirs", [])
        base_dir = data.get("base_dir", "")
        
        if not moves:
            return {"logs": ["Історія сортування порожня."], "has_history": False}
            
        success_count = 0
        # Скасовуємо у зворотному порядку
        for move in reversed(moves):
            original = Path(move["original"])
            new = Path(move["new"])
            
            if new.exists():
                try:
                    original.parent.mkdir(parents=True, exist_ok=True)
                    shutil.move(str(new), str(original))
                    logs.append(f"[ПОВЕРНЕНО] '{new.name}' -> '{original.name}'")
                    success_count += 1
                except Exception as e:
                    logs.append(f"[ПОМИЛКА] Не вдалося повернути '{new.name}': {e}")
            else:
                logs.append(f"[УВАГА] Файл не знайдено за новим шляхом: '{new.name}'")
                
        # Видаляємо створені папки, якщо вони порожні
        for dir_path_str in reversed(created_dirs):
            dir_path = Path(dir_path_str)
            if dir_path.exists() and dir_path.is_dir():
                try:
                    if not any(dir_path.iterdir()):
                        dir_path.rmdir()
                        logs.append(f"[ВИДАЛЕНО ПУСТУ ПАПКУ] '{dir_path.name}'")
                except Exception:
                    pass
                    
        # Очищуємо також стандартні папки категорій у базовій директорії, якщо вони тепер порожні
        if base_dir:
            base_path = Path(base_dir)
            for cat in list(FILE_CATEGORIES.keys()) + ["Інші файли", "Дублікати"]:
                cat_dir = base_path / cat
                if cat_dir.exists() and cat_dir.is_dir():
                    try:
                        if not any(cat_dir.iterdir()):
                            cat_dir.rmdir()
                    except Exception:
                        pass
                        
        # Видаляємо файл історії
        try:
            self.history_file.unlink()
        except Exception:
            pass
            
        logs.append(f"\n--- Скасування завершено. Повернуто файлів: {success_count} ---")
        return {"logs": logs, "has_history": False}

    def get_destination_folder(self, file_path, target_path, sort_mode, categories_filter):
        ext = file_path.suffix.lower()
        
        # Якщо режим сортування за типом
        if sort_mode == "type":
            dest_cat = "Інші файли"
            for cat, extensions in FILE_CATEGORIES.items():
                if ext in extensions:
                    dest_cat = cat
                    break
            
            # Перевіряємо, чи увімкнено цю категорію у фільтрі
            if not categories_filter.get(dest_cat, True):
                return None
                
            return target_path / dest_cat
            
        # Якщо режим сортування за датою
        elif sort_mode == "date":
            # Визначаємо категорію, щоб перевірити фільтр
            dest_cat = "Інші файли"
            for cat, extensions in FILE_CATEGORIES.items():
                if ext in extensions:
                    dest_cat = cat
                    break
                    
            if not categories_filter.get(dest_cat, True):
                return None
                
            # Отримуємо дату зміни файлу
            stat = file_path.stat()
            file_time = datetime.fromtimestamp(stat.st_mtime)
            year = str(file_time.year)
            month_num = file_time.month
            month_name = MONTHS_UA[month_num]
            
            folder_name = f"{year}-{month_num:02d}_{month_name}"
            return target_path / year / folder_name
            
        return None

    def unique_dest_path(self, dest_folder, file_name):
        base = file_name.stem
        ext = file_name.suffix
        counter = 1
        new_name = file_name.name
        
        while (dest_folder / new_name).exists():
            new_name = f"{base} ({counter}){ext}"
            counter += 1
            
        return dest_folder / new_name

    def sort_files(self, folder_path, sort_mode, categories, dry_run, detect_duplicates=False):
        logs = []
        
        if not folder_path or not os.path.exists(folder_path):
            return {"error": "Вказана папка не існує!"}
            
        target_path = Path(folder_path)
        action_word = "Попередній перегляд" if dry_run else "Сортування"
        
        # Виключені папки (категорії, дати та службові)
        excluded_names = {"Відео", "Зображення", "Документи", "Аудіо", "Архіви", "Дублікати", "Інші файли"}
        def is_excluded_dir(path):
            if path.name in excluded_names:
                return True
            if path.name.isdigit() and len(path.name) == 4:
                return True
            return False

        def get_directory_category_and_files(dir_path):
            # Рекурсивно знаходимо всі файли в підпапці
            all_files = []
            for root, _, filenames in os.walk(dir_path):
                for fname in filenames:
                    if fname.startswith('.'):
                        continue
                    all_files.append(Path(root) / fname)
            
            if not all_files:
                return None, [] # Порожня папка
                
            first_cat = None
            for file_path in all_files:
                ext = file_path.suffix.lower()
                cat = "Інші файли"
                for c, extensions in FILE_CATEGORIES.items():
                    if ext in extensions:
                        cat = c
                        break
                
                if first_cat is None:
                    first_cat = cat
                elif first_cat != cat:
                    return "mixed", all_files # Змішана папка
                    
            return first_cat, all_files # Чиста папка певної категорії
        
        # Шукаємо файли та підпапки у корені
        files_to_sort = []
        dirs_to_sort = []
        try:
            for item in target_path.iterdir():
                if item.name.startswith('.'):
                    continue
                if item.is_file():
                    files_to_sort.append(item)
                elif item.is_dir() and not is_excluded_dir(item):
                    dirs_to_sort.append(item)
            # Сортуємо алфавітно за назвою для стабільного порядку обробки
            files_to_sort.sort(key=lambda x: x.name.lower())
            dirs_to_sort.sort(key=lambda x: x.name.lower())
        except Exception as e:
            return {"error": f"Не вдалося отримати доступ до папки: {e}"}
            
        if not files_to_sort and not dirs_to_sort:
            logs.append("У цій папці немає файлів чи підпапок для сортування.")
            logs.append("--- Процес завершено ---")
            return {"logs": logs, "has_history": self.check_history_exists()}
            
        moved_count = 0
        ignored_count = 0
        duplicate_count = 0
        
        # Ініціалізуємо структури для історії
        history = {
            "base_dir": str(target_path),
            "moves": [],
            "created_dirs": []
        }
        
        # Словник для дублікатів
        file_hashes = {}
        
        def record_dir_creation(dir_path):
            if not dir_path.exists():
                parents_to_create = []
                p = dir_path
                while p != target_path and p != p.parent:
                    if not p.exists():
                        parents_to_create.append(p)
                    p = p.parent
                for p in reversed(parents_to_create):
                    p_str = str(p)
                    if p_str not in history["created_dirs"]:
                        history["created_dirs"].append(p_str)

        # Спочатку сортуємо чисті підпапки
        for dir_path in dirs_to_sort:
            cat, dir_files = get_directory_category_and_files(dir_path)
            
            if cat == "mixed":
                ignored_count += 1
                logs.append(f"[ПРОПУЩЕНО] Папка '{dir_path.name}' містить змішані файли (не сортуємо)")
                continue
            elif cat is None:
                ignored_count += 1
                logs.append(f"[ПРОПУЩЕНО] Папка '{dir_path.name}' порожня")
                continue
                
            # Чиста папка - перевіряємо, чи увімкнено її категорію
            if not categories.get(cat, True):
                ignored_count += 1
                continue
                
            # Отримуємо цільову папку для папки
            if sort_mode == "type":
                dest_folder = target_path / cat
            elif sort_mode == "date":
                # Визначаємо дату за найновішим файлом у цій папці
                newest_file = max(dir_files, key=lambda f: f.stat().st_mtime)
                stat = newest_file.stat()
                file_time = datetime.fromtimestamp(stat.st_mtime)
                year = str(file_time.year)
                month_num = file_time.month
                month_name = MONTHS_UA[month_num]
                folder_name = f"{year}-{month_num:02d}_{month_name}"
                dest_folder = target_path / year / folder_name
            else:
                dest_folder = None
                
            if dest_folder is None:
                ignored_count += 1
                continue
                
            if dir_path.parent == dest_folder:
                continue
                
            dest_dir_path = self.unique_dest_path(dest_folder, dir_path)
            rel_dest = dest_dir_path.relative_to(target_path)
            
            if dry_run:
                logs.append(f"[ПЛАНУЄТЬСЯ] Папку '{dir_path.name}' (тільки {cat.lower()}) -> в '{rel_dest}'")
            else:
                try:
                    record_dir_creation(dest_folder)
                    dest_folder.mkdir(parents=True, exist_ok=True)
                    shutil.move(str(dir_path), str(dest_dir_path))
                    logs.append(f"[УСПІШНО] Папку '{dir_path.name}' -> перенесено в '{rel_dest}'")
                    history["moves"].append({
                        "original": str(dir_path),
                        "new": str(dest_dir_path)
                    })
                except Exception as e:
                    logs.append(f"[ПОМИЛКА] Не вдалося перемістити папку '{dir_path.name}': {e}")
                    
            moved_count += 1

        # Далі сортуємо окремі файли в корені
        for file_path in files_to_sort:
            # Перевіряємо дублікати
            is_duplicate = False
            original_file = None
            
            if detect_duplicates:
                f_hash = self.get_file_md5(file_path)
                if f_hash in file_hashes:
                    is_duplicate = True
                    original_file = file_hashes[f_hash]
                else:
                    file_hashes[f_hash] = file_path
            
            if is_duplicate:
                dest_folder = target_path / "Дублікати"
                dest_file_path = self.unique_dest_path(dest_folder, file_path)
                rel_dest = dest_file_path.relative_to(target_path)
                
                if dry_run:
                    logs.append(f"[ДУБЛІКАТ] '{file_path.name}' є копією '{original_file.name}' -> буде перенесено в '{rel_dest.parent}'")
                else:
                    try:
                        record_dir_creation(dest_folder)
                        dest_folder.mkdir(parents=True, exist_ok=True)
                        shutil.move(str(file_path), str(dest_file_path))
                        logs.append(f"[ДУБЛІКАТ] '{file_path.name}' -> перенесено в '{rel_dest}'")
                        history["moves"].append({
                            "original": str(file_path),
                            "new": str(dest_file_path)
                        })
                    except Exception as e:
                        logs.append(f"[ПОМИЛКА] Не вдалося перемістити дублікат '{file_path.name}': {e}")
                
                duplicate_count += 1
                moved_count += 1
                continue

            # Звичайне сортування файлу
            dest_folder = self.get_destination_folder(file_path, target_path, sort_mode, categories)
            
            if dest_folder is None:
                ignored_count += 1
                continue
                
            if file_path.parent == dest_folder:
                continue
                
            dest_file_path = self.unique_dest_path(dest_folder, file_path)
            
            rel_source = file_path.name
            rel_dest = dest_file_path.relative_to(target_path)
            
            if dry_run:
                logs.append(f"[ПЛАНУЄТЬСЯ] '{rel_source}' -> в '{rel_dest.parent}'")
            else:
                try:
                    record_dir_creation(dest_folder)
                    dest_folder.mkdir(parents=True, exist_ok=True)
                    shutil.move(str(file_path), str(dest_file_path))
                    logs.append(f"[УСПІШНО] '{rel_source}' -> '{rel_dest}'")
                    history["moves"].append({
                        "original": str(file_path),
                        "new": str(dest_file_path)
                    })
                except Exception as e:
                    logs.append(f"[ПОМИЛКА] Не вдалося перемістити '{rel_source}': {e}")
                    
            moved_count += 1
            
        logs.append(f"\n--- {action_word} завершено ---")
        if dry_run:
            logs.append(f"Буде впорядковано об'єктів: {moved_count}")
            if detect_duplicates:
                logs.append(f"З них дублікатів: {duplicate_count}")
            logs.append(f"Проігноровано/пропущено: {ignored_count}")
            logs.append("Жодних змін на диску не було проведено.")
        else:
            logs.append(f"Успішно впорядковано об'єктів: {moved_count}")
            if detect_duplicates:
                logs.append(f"З них перенесено як дублікати: {duplicate_count}")
            logs.append(f"Проігноровано/пропущено: {ignored_count}")
            
            # Зберігаємо історію
            if history["moves"]:
                try:
                    with open(self.history_file, "w", encoding="utf-8") as f:
                        json.dump(history, f, ensure_ascii=False, indent=4)
                except Exception as e:
                    logs.append(f"[УВАГА] Не вдалося зберегти історію сортування: {e}")
            else:
                if self.history_file.exists():
                    self.history_file.unlink()
                    
        return {"logs": logs, "has_history": self.check_history_exists()}

def setup_mac_app_identity():
    try:
        import sys
        from AppKit import NSApplication, NSImage
        shared_app = NSApplication.sharedApplication()
        
        if hasattr(sys, '_MEIPASS'):
            icon_path = Path(sys._MEIPASS) / "web_ui" / "app_icon.png"
        else:
            icon_path = Path(__file__).parent / "web_ui" / "app_icon.png"
            
        if icon_path.exists():
            image = NSImage.alloc().initWithContentsOfFile_(str(icon_path))
            shared_app.setApplicationIconImage_(image)
    except Exception as e:
        pass

def main():
    setup_mac_app_identity()
    api = Api()
    
    import sys
    if hasattr(sys, '_MEIPASS'):
        current_dir = Path(sys._MEIPASS)
    else:
        current_dir = Path(__file__).parent
        
    html_path = current_dir / "web_ui" / "index.html"
    
    window = webview.create_window(
        title="Розумний сортувальник файлів",
        url=str(html_path.resolve()),
        js_api=api,
        width=1160,
        height=820,
        resizable=True,
        min_size=(1080, 760),
        background_color="#0b0d12"
    )
    
    api.set_window(window)
    webview.start(debug=False)

if __name__ == "__main__":
    main()
