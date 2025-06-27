LockIn Tracker

## Opis projektu
LockIn Tracker to mobilna aplikacja Flutter do śledzenia aktywności i celów osobistych. Umożliwia użytkownikom monitorowanie czasu poświęconego na zadania (np. nauka, praca) oraz liczby ukończeń dla aktywności typu check-list (np. pójście na siłownie). Aplikacja wspiera definiowanie celów dziennych, tygodniowych i miesięcznych, wyświetlanie statystyk oraz przeglądanie historii aktywności.

Projekt został stworzony jako indywidualna inicjatywa, z naciskiem na prostotę, intuicyjność i funkcjonalność.

## Funkcjonalności
- **Śledzenie aktywności**: Rejestracja czasu (timer) dla aktywności czasowych lub liczby ukończeń dla aktywności checkable.
- **Cele**: Ustawianie celów dla każdej aktywności z określonym typem (dzienny, tygodniowy, miesięczny) oraz datami rozpoczęcia i zakończenia.
- **Statystyki**: Wykresy słupkowe (biblioteka `fl_chart`) pokazujące czas i ukończenia w wybranym okresie (dzień, tydzień, miesiąc, cały czas).
- **Historia**: Przegląd aktywności i postępu celów z podziałem na dni, z kolorowymi wskaźnikami postępu.
- **Zarządzanie aktywnościami**: Dodawanie, edytowanie, usuwanie i zmiana kolejności aktywności (maks. 10).
- **Ustawienia**: Przełączanie między trybem jasnym a ciemnym oraz resetowanie wszystkich danych.
- **Persystencja danych**: Przechowywanie aktywności, logów i celów w `SharedPreferences`.

## Struktura projektu
- **Modele** (`models/`):
    - `activity.dart`: Abstrakcyjna klasa `Activity` oraz klasy `TimedActivity` i `CheckableActivity`.
    - `goal.dart`: Klasa `Goal` dla celów z typami (dzienny, tygodniowy, miesięczny).
    - `activity_log.dart`: Klasa `ActivityLog` do przechowywania logów aktywności.
- **Strony** (`pages/`):
    - `home_page.dart`: Główna strona z zakładkami (Tracker, Goals, Activities, Stats, History).
    - `tracker_page.dart`: Interfejs do śledzenia aktywności (timer, ręczne dodawanie/odejmowanie).
    - `goals_page.dart`: Ustawianie i edycja celów dla aktywności.
    - `activities_page.dart`: Zarządzanie listą aktywności.
    - `stats_page.dart`: Wizualizacja statystyk w formie wykresów.
    - `history_page.dart`: Przegląd historii z postępem celów.
    - `settings_page.dart`: Ustawienia motywu i reset danych.
- **Utils** (`utils/`):
    - `format_utils.dart`: Funkcja formatowania czasu (`HH:mm:ss`).

## Wymagania
- Flutter SDK (zalecana wersja: najnowsza stabilna)
- Zależności:
    - `shared_preferences`: Do przechowywania danych.
    - `fl_chart`: Do wizualizacji statystyk.
    - `flutter/services`: Do filtrowania danych wejściowych.

## Instalacja
1. Skopiuj repozytorium:
   ```bash
   git clone <adres-repozytorium>
   ```
2. Zainstaluj zależności:
   ```bash
   flutter pub get
   ```
3. Uruchom aplikację:
   ```bash
   flutter run
   ```