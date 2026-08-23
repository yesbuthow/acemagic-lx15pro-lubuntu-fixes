# ACEMAGIC LX15PRO + Lubuntu 26.04 — note italiane

Repository nato dal troubleshooting reale di un ACEMAGIC LX15PRO con Ryzen 7 7730U e grafica AMD Barcelo/Renoir.

## Problemi risolti

1. **Schermo interno nero al boot**
   - `7.0.0-30-generic`: problematico.
   - `7.0.0-14-generic`: accelerazione AMD funzionante, ma pannello eDP nero senza HDMI già collegato.
   - `7.0.0-1011-oem`: boot corretto del pannello interno senza HDMI.

2. **Ibernazione non disponibile**
   - Secure Boot attivo causava kernel lockdown e bloccava l'ibernazione.
   - Con Secure Boot disabilitato compariva `disk` in `/sys/power/state`.

3. **Resume da swapfile incompleto**
   - `resume_offset` veniva caricato.
   - `/sys/power/resume` restava `0:0`.
   - Ubuntu 26.04 usa `dracut`: aggiungendo il modulo `resume` all'initrd il device veniva finalmente popolato.

4. **Schermi neri dopo il resume**
   - la sessione RAM veniva ripristinata correttamente;
   - AMDGPU riportava errori DMCUB;
   - un ciclo `eDP OFF -> ON` più `DPMS ON` recuperava il display.

5. **Password al ritorno**
   - LXQt e XScreenSaver stavano tentando entrambi di gestire il lock prima dello sleep;
   - è stato disabilitato il lock aggiuntivo di LXQt (`lock_screen_before_power_actions=false`);
   - lo script blocca esplicitamente XScreenSaver prima di ibernare.

## Risultato finale

Il launcher `Iberna` fa:

```text
click
 -> lock XScreenSaver
 -> hibernate
 -> spegnimento completo
 -> Power
 -> resume RAM
 -> ripristino display automatico
 -> richiesta password utente
```

Il workaround display misurato nell'ultimo test aggiunge circa 0,15 secondi dopo il vero resume.

Leggere `README.md` e `docs/` prima di applicare la configurazione.
