# kiss_simplequeue

A simple, backend-agnostic queue interface for Dart — part of the [KISS](https://pub.dev/publishers/your-publisher-name-here) (Keep It Simple, Stupid) family of libraries.

## 🎯 Purpose

`kiss_simplequeue` helps you write async, event-based logic without locking into a specific backend. Whether you're using Firebase, AWS SQS, or a custom queue, this library gives you a unified interface with minimal fuss.

Just queues. No ceremony. No complexity.

---

## ✨ Features

- ✅ Generic `EventQueue` interface
- ✅ Firestore adapter (for Firebase-native apps)
- ✅ AWS SQS adapter (for scale and reliability)
- ✅ Swappable backends with a single line change
- ✅ Minimalist, developer-friendly design
