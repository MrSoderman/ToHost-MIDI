# Software ToHost-MIDI (real-time Serial to MPU-401 converter)

## Installation Notes

Created by **Jimmy Söderman Sers**

---

### Getting Started

Boot the computer from the media.  
No changes to hardware or storage.  
To shut down, simply power off the computer.

**Requires:**  
- PC with CD/DVD/BD drive  
- Legacy RS-232 serial port  
- Joystick port with MPU-401 adapter  
(No monitor or keyboard needed.)

---

### Installation

1. Burn the ISO to CD/DVD/BD with any USB burning software (e.g., Balena Etcher).  
2. Ensure booting from external media is enabled, boot order is correct, and SATA-native mode is disabled.  
3. Some PCs may require a keyboard to boot.

---

### Functionality

Emulates a MIDI ToHost device, transferring MIDI data between the serial port and MPU-401 interface in real time — with no lag or lost data.

---

### TO HOST Standard

- **Communication:** RS-232 at 38400 bps, no parity, 1 start bit, 8 data bits, 1 stop bit  
- **Mode:** Multimode unsupported — use normal mode

#### Supported Devices

**Roland:** SoundCanvas series, PMA-5, SK, XP, HP-G, KR, RSS-10  
**Yamaha:** QY, QS, VL, CS, MU series, CBX-K1XG, Disklavier, Clavinova, mixers  
**Kawai:** GMega, K5000  
**Korg:** 05RW, X5, N-series, EC120, E320, I-Series  
**Alesis:** QuadraSynth, S4 Plus, QS series, Nanosynth

---

### License

MIT License © 2010 Jimmy Söderman Sers  
See the [LICENSE](LICENSE) file for full license text.
