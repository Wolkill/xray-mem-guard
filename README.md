# xray-mem-guard

Автоматически перезапускает ядро **Xray** на сервере с панелью **3X-UI**, когда
использование оперативной памяти превышает заданный порог (по умолчанию **80%**).

Небольшие VPS (512 МБ – 1 ГБ) без swap часто упираются в потолок памяти из-за
постепенного роста потребления ядром Xray. Когда память заканчивается, ядро
может быть убито OOM-киллером или начать тормозить. Этот «сторож» проверяет
память раз в минуту и, если она превысила порог, перезапускает сервис `x-ui`
(вместе с ним перезапускается и ядро Xray), освобождая память.

## Как это работает

- Раз в минуту systemd-таймер запускает скрипт `xray-mem-guard.sh`.
- Скрипт считает **реальное** использование памяти:
  `(MemTotal − MemAvailable) / MemTotal`.
  `MemAvailable` уже вычитает освобождаемый кэш, поэтому это честная метрика
  нагрузки, а не пугающие «90%», которые даёт наивное `total − free`.
- Если значение ≥ `THRESHOLD` (80%) **и** с прошлого перезапуска прошло больше
  `COOLDOWN` секунд — выполняется `systemctl restart x-ui`.
- Всё пишется в `/var/log/xray-mem-guard.log`.
- `COOLDOWN` (по умолчанию 10 минут) защищает от «шторма» перезапусков, если
  память держится высокой.

## Требования

- Linux с **systemd** (Ubuntu / Debian и подобные).
- Панель 3X-UI, установленная как сервис `x-ui` (проверка: `systemctl status x-ui`).
- Права root.

## Установка

```bash
git clone https://github.com/<your-github>/xray-mem-guard.git
cd xray-mem-guard
sudo bash install.sh
```

Установщик:
- копирует `xray-mem-guard.sh` в `/usr/local/bin/`;
- ставит systemd-юниты `xray-mem-guard.service` и `xray-mem-guard.timer`;
- создаёт конфиг `/etc/xray-mem-guard.conf` (если его ещё нет);
- включает и запускает таймер.

## Настройка

Отредактируйте `/etc/xray-mem-guard.conf`:

```bash
THRESHOLD=80                          # порог в процентах
COOLDOWN=600                          # минимум секунд между перезапусками
RESTART_CMD="systemctl restart x-ui"  # команда перезапуска ядра
LOG="/var/log/xray-mem-guard.log"
```

Перезапускать ничего не нужно — новые значения подхватятся при следующей проверке.

## Проверка

```bash
# Статус таймера и время следующего запуска
systemctl status xray-mem-guard.timer
systemctl list-timers xray-mem-guard.timer

# Прогнать проверку прямо сейчас
# (безопасно: перезапустит ТОЛЬКО если память выше порога)
sudo /usr/local/bin/xray-mem-guard.sh

# Логи
tail -f /var/log/xray-mem-guard.log
journalctl -u xray-mem-guard.service -f
```

## Удаление

```bash
sudo bash uninstall.sh
```

## Почему перезапускается весь сервис `x-ui`, а не «только Xray»?

В 3X-UI ядро Xray запускается и контролируется процессом панели `x-ui`.
Отдельного systemd-юнита у ядра нет, поэтому надёжный способ перезапустить именно
ядро — перезапустить сервис `x-ui`: панель поднимается за секунду и заново
запускает Xray с актуальным конфигом. Нужен другой способ — поменяйте
`RESTART_CMD` в конфиге.

## Совет для VPS с 1 ГБ RAM без swap

Перезапуск лечит симптом. Чтобы реже упираться в память, можно добавить
небольшой swap:

```bash
sudo fallocate -l 1G /swapfile && sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

## Лицензия

MIT — см. [LICENSE](LICENSE).
