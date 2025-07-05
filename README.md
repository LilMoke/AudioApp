
# AudioApp

An iOS app that records audio in userc defined segments, transcribes them using OpenAI Whisper with local Apple Speech as a fallback method.  
In the settings view there are configurable audios settings. In addition to transcribing the audio the user can optioanlly save the recordings securely on their device.

---

## Features

- Transcribe using **OpenAI Whisper API** with fallback to **Apple Speech Framework**
- Recording Controls to start/stop/pause recording
- Session List grouped by date
- Session Detail with transcription status and text
- Adjustable sample rate, bit depth, and file format: `wav`, `caf` or `m4a`
- Live updates during recording and transcription
- Smooth scrolling
- Full VoiceOver accessibility support
- Record audio in 10–120 sec segments, configurable by the user settings
- Option in user settings to keep audio clips after transcription


---

## Setup Instructions

### Requirements
- Xcode 15+
- iOS 17+ device or simulator

---

### Clone the repo
```bash
git clone https://github.com/LilMoke/AudioApp
cd AudioApp
```

---

### Open in Xcode
Double-click `AudioApp.xcodeproj`

---

### Set your OpenAI API Key
- Run the app on your simulator or device
- Go to **Settings (⚙️ icon)**
- Choose **Use OpenAI Whisper**, then enter your API Key. Your key is stored securely in the iOS Keychain.

---

### Build & Run
- Select the target simulator or device
- Click **Run ▶️** in Xcode

---

## Developer Notes

- **Data Storage**  
  - Audio segments are stored in either `Documents/`, if “Keep Audio Clips” is on or `tmp/` and auto-deleted after transcription.
  - SwiftData models: `RecordingSession`, `AudioSegment`, `Transcription` to track all sessions and metadata.

- **Audio Engine**  
  - Uses `AVAudioEngine` for low-latency recording.
  - Automatically handles interruptions (e.g., bluetooth ear bud, phone calls, unplugged headphones).

- **Transcription**  
  - Optioally choose to use Apple `SFSpeechRecognizer` only, or OpenAI Whisper via HTTP multipart upload with Apple `SFSpeechRecognizer`

- **Security**  
  - OpenAI API Key is stored in Keychain.
  - Files are not encrypted at rest in this prototype (see `Known Issues`).

---

## Known Issues / Future Enhancements
- Audio files are renamed for user’s chosen extension, but not truly re-encoded.
- Files not encrypted on disk (would use `NSFileProtection` or AES).
- No deduplication or cleanup of orphaned files if crash occurs during save.

---

## Contact
For questions contact:
```
me@email.com
```

---
