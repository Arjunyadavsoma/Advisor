# AI Advisor - Flutter AI Chat Application

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" />
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" />
  <img src="https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge" />
</p>

A sophisticated Flutter application that enables users to engage in meaningful conversations with AI-powered representations of history's greatest minds. Chat with renowned philosophers, strategic thinkers, and success authors through an intuitive and beautifully designed interface.

## ✨ Features

### 🧠 **AI Personalities**
- **Ancient Philosophers**: Socrates, Plato, and other classical thinkers
- **Strategic Authors**: Sun Tzu and military strategists  
- **Success Authors**: Stephen Covey and productivity experts
- **Spiritual Leaders**: Rumi and mystical poets

### 🔐 **Authentication & User Management**
- Email/password authentication
- Google Sign-In integration
- User profile management
- Activity tracking and statistics

### 📊 **User Dashboard**
- Conversation count tracking
- Message statistics
- Favorites system
- User level progression
- Streak tracking

### 💬 **Chat Experience**
- Real-time AI responses
- Clean, intuitive chat interface
- Character-specific personality traits
- Conversation history

### 🎨 **Modern UI/UX**
- Material Design principles
- Dark/Light mode support
- Smooth animations and transitions
- Responsive design for all screen sizes

## 📱 Screenshots

| Login Screen | Character Selection | User Profile | Chat Interface |
|:---:|:---:|:---:|:---:|
| ![Login](Screenshot_20250927_045541.jpg5shot_20250927_050 🛠️ Tech Stack

- **Frontend**: Flutter & Dart
- **Authentication**: Firebase Authentication
- **Backend**: Firebase (Firestore/Realtime Database)
- **State Management**: Provider/Riverpod
- **AI Integration**: Custom AI API integration
- **Architecture**: Clean Architecture with MVVM pattern

## 📋 Prerequisites

Before running this application, make sure you have:

- Flutter SDK (>=3.0.0)
- Dart SDK (>=2.17.0)
- Android Studio / VS Code
- Firebase project setup
- AI API credentials

## 🚀 Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/ai-advisor-flutter.git
   cd ai-advisor-flutter
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   - Create a new Firebase project
   - Enable Authentication (Email/Password and Google Sign-In)
   - Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Configure Firestore database

4. **Environment Configuration**
   ```bash
   cp .env.example .env
   ```
   Add your API keys:
   ```
   AI_API_KEY=your_ai_api_key_here
   FIREBASE_API_KEY=your_firebase_api_key
   ```

5. **Run the application**
   ```bash
   flutter run
   ```

## 🏗️ Project Structure

```
lib/
├── core/
│   ├── constants/
│   ├── utils/
│   └── exceptions/
├── data/
│   ├── models/
│   ├── repositories/
│   └── services/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
├── presentation/
│   ├── pages/
│   ├── widgets/
│   └── providers/
└── main.dart
```

## 🎯 Usage

1. **Sign Up/Login**: Create an account or sign in with Google
2. **Choose Character**: Browse through different categories of historical figures
3. **Start Chatting**: Engage in conversations and learn from AI-powered personalities
4. **Track Progress**: Monitor your activity and conversation statistics
5. **Explore Features**: Discover favorites, streaks, and level progression

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👨‍💻 Developer

**Soma Arjun Yadav**
- B.Tech AI & ML Student at VJIT Hyderabad
- Email: arjunyadav35763@gmail.com
- LinkedIn: [Your LinkedIn Profile]
- GitHub: [@yourusername]

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase for backend services
- All the historical figures who inspired this project
- Open source community for continuous support

## 📞 Support

If you found this project helpful, please give it a ⭐️!

For support, email arjunyadav35763@gmail.com or create an issue in this repository.

***

**Built with ❤️ using Flutter**

[1](https://github.com/farrelad/flutter-ai-chat-app)
[2](https://github.com/topics/flutter-chat-app)
[3](https://github.com/flyerhq/flutter_chat_ui)
[4](https://pub.dev/packages/flutter_gen_ai_chat_ui)
[5](https://www.walturn.com/insights/how-to-create-an-effective-flutter-readme)
[6](https://github.com/iampawan/ChatGPT-Flutter-AIChatBot)
[7](https://github.com/leehack/flutter-mcp-ai-chat)
[8](https://github.com/topics/flutter-chat-ui-template)
[9](https://github.com/HarshAndroid/ApnaChat-Realtime-Chat-App-In-Flutter-Firebase)
[10](https://github.com/flutter/ai)
