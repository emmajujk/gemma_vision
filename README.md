# Gemma Vision (Learning Fork)

A modified version of Gemma Vision, an AI vision assistant for the blind built with Google’s Gemma model.

This repository is based on the original project by TGTech06:
https://github.com/TGTech06/gemma-vision

I cloned this project to study and learn from its architecture and implementation.  
I also added support for importing local LiteRT Gemma models from device storage, including:
- Gemma-4-E2B-it-LiteRT-LM

## Original Project Features

- **8BitDo controller support** for hands-free operation  
- **Offline AI processing** after initial model download  
- **Complete privacy** — nothing leaves your device  
- **Scene description** and text reading  
- **Ask follow-up questions** — Gemma remembers previous photos you've sent  
- **Screen reader optimized** for VoiceOver and TalkBack  

## My Modifications

- Added support for importing AI models directly from device storage
- Tested with:
  - Gemma-4-E2B-it-LiteRT-LM
- Learning and experimenting with Flutter + on-device AI integration

## Original Project Setup

1. Install APK  
2. Download AI model (~3 GB)  
3. Grant camera & mic permissions  
4. Connect an 8BitDo controller in Keyboard Mode, then open the **8BitDo Ultimate Software** app and map your buttons as shown below:  

![Controller Setup Instructions](assets/controller_setup.png)

5. Go into settings in the app to learn more about what each button on the controller does  
6. It is recommended to switch off VoiceOver/TalkBack when using the controller  

## Development

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git
cd YOUR_REPO
flutter pub get
flutter run
