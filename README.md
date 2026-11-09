# Miyawana Defense — Game Design Document (GDD) & Technical Spec

> **A Tactical Side-Defense & Idle Base-Building Auto-Battler with Chibi Cats**  
> Built with **Godot Engine 4.x** (GDScript) | Platform: PC (Mouse-only / Mobile adaptable)

---

## 1. Executive Summary & Core Game Loop

**Miyawana Defense** combines the tactical positioning of lane-based auto-battlers with lightweight idle progression and hero gacha collection. 

Designed for a 3-month development cycle, the technical focus is placed on a **clean, decoupled, data-driven architecture** in Godot 4, procedural animation using run-time `Tween` nodes, dynamic facial expression states, and persistent state management.