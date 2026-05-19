import os
import shutil
import json
from pathlib import Path
from file_sorter_web import Api, FILE_CATEGORIES

def setup_sandbox(sandbox_path):
    if sandbox_path.exists():
        shutil.rmtree(sandbox_path)
    sandbox_path.mkdir(parents=True, exist_ok=True)
    
    # Створюємо унікальні файли
    (sandbox_path / "video1.mp4").write_text("unique video content 1")
    (sandbox_path / "song.mp3").write_text("unique audio content")
    (sandbox_path / "doc1.pdf").write_text("unique document content")
    
    # Створюємо дублікати (однаковий вміст, різні назви)
    (sandbox_path / "image.png").write_text("duplicate image content")
    (sandbox_path / "image_copy.png").write_text("duplicate image content")
    (sandbox_path / "image_another_copy.png").write_text("duplicate image content")

def test_full_cycle():
    sandbox = Path(__file__).parent / "test_sandbox"
    setup_sandbox(sandbox)
    
    print("--- ЗАПУСК ТЕСТУВАННЯ СОРТУВАННЯ ТА СКАСУВАННЯ ---")
    
    api = Api()
    if api.history_file.exists():
        api.history_file.unlink()
    
    # Фільтр категорій (всі увімкнені)
    categories = {cat: True for cat in FILE_CATEGORIES.keys()}
    categories["Інші файли"] = True
    
    # 1. Перевіряємо запуск у режимі Dry Run (попередній перегляд)
    print("\n1. Тестування попереднього перегляду (dry_run=True)...")
    res_dry = api.sort_files(str(sandbox), "type", categories, dry_run=True, detect_duplicates=True)
    
    # Перевіримо, що файли не перемістилися насправді
    assert (sandbox / "video1.mp4").exists()
    assert (sandbox / "image_copy.png").exists()
    assert not api.check_history_exists(), "Dry run не повинен створювати файл історії"
    print("✓ Попередній перегляд працює коректно (файли залишились на місці)")
    
    # 2. Запуск справжнього сортування з виявленням дублікатів
    print("\n2. Тестування реального сортування з пошуком дублікатів...")
    res_real = api.sort_files(str(sandbox), "type", categories, dry_run=False, detect_duplicates=True)
    
    # Перевіряємо результати сортування
    assert (sandbox / "Відео" / "video1.mp4").exists(), "video1.mp4 має бути у папці 'Відео'"
    assert (sandbox / "Аудіо" / "song.mp3").exists(), "song.mp3 має бути у папці 'Аудіо'"
    assert (sandbox / "Документи" / "doc1.pdf").exists(), "doc1.pdf має бути у папці 'Документи'"
    
    # Перевіряємо дублікати
    # Перший файл image.png повинен відправитися в Зображення
    # Другий та третій (image_copy.png, image_another_copy.png) — в Дублікати
    assert (sandbox / "Зображення" / "image.png").exists(), "Перший унікальний файл має бути у 'Зображення'"
    assert (sandbox / "Дублікати" / "image_copy.png").exists(), "Дублікат 1 має бути у папці 'Дублікати'"
    assert (sandbox / "Дублікати" / "image_another_copy.png").exists(), "Дублікат 2 має бути у папці 'Дублікати'"
    
    # Перевіряємо файл історії
    assert api.check_history_exists(), "Має створитися файл історії last_session.json"
    
    with open(api.history_file, "r", encoding="utf-8") as f:
        history_data = json.load(f)
    assert len(history_data["moves"]) == 6, "Має бути записано 6 успішних переміщень"
    print("✓ Сортування та виявлення дублікатів пройшли успішно")
    
    # 3. Тестування скасування сортування (Undo)
    print("\n3. Тестування функції скасування сортування (Undo)...")
    res_undo = api.undo_sorting()
    
    # Перевіряємо, чи всі файли повернулися назад
    expected_original_files = [
        "video1.mp4", "song.mp3", "doc1.pdf",
        "image.png", "image_copy.png", "image_another_copy.png"
    ]
    for f_name in expected_original_files:
        assert (sandbox / f_name).exists(), f"Файл {f_name} мав повернутися на вихідне місце"
        
    # Перевіряємо, чи видалилися створені папки
    assert not (sandbox / "Відео").exists(), "Папка 'Відео' має бути видалена після скасування"
    assert not (sandbox / "Аудіо").exists(), "Папка 'Аудіо' має бути видалена після скасування"
    assert not (sandbox / "Документи").exists(), "Папка 'Документи' має быть видалена після скасування"
    assert not (sandbox / "Зображення").exists(), "Папка 'Зображення' має бути видалена після скасування"
    assert not (sandbox / "Дублікати").exists(), "Папка 'Дублікати' має бути видалена після скасування"
    
    # Перевіряємо файл історії
    assert not api.check_history_exists(), "Файл історії має бути видалено після успішного скасування"
    print("✓ Скасування (Undo) працює бездоганно (всі файли та папки відновлено)")
    
    print("\nУСІ АВТОМАТИЧНІ ТЕСТИ УСПІШНО ПРОЙДЕНО! 🎉")
    
    # Очищення
    if sandbox.exists():
        shutil.rmtree(sandbox)

if __name__ == "__main__":
    test_full_cycle()
