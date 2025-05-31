# komarigoto_app

A new Flutter project.

## プロジェクト概要

このプロジェクトは、Flutterを使用して構築された食材在庫管理＆レシピ提案アプリです。以下の主要な機能を提供します：

- **食材の在庫管理**: 食材の追加、削除、編集、在庫状況の更新。
- **レシピ提案**: 在庫食材とユーザー条件に基づいたAIによるレシピ提案。
- **ユーザー設定**: 節約、健康、時短などの重視ポイントを設定可能。
- **レシピ検索・保存・シェア**: レシピの生成、保存、共有、ランキング機能。

## アーキテクチャ

このプロジェクトは、クリーンアーキテクチャおよびMVVMパターンを採用しています。

### 構成図（マーメイド記法）

```mermaid
graph TD
  %% "Presentation層"
  subgraph "Presentation層"
    A1["View (Widget)"]
    A2["ViewModel (StateNotifier/Provider)"]
    A1 -- "UIイベント/状態監視" --> A2
  end

  %% "Domain層"
  subgraph "Domain層"
    B1["Entity"]
    B2["UseCase"]
    B3["Repositoryインターフェース"]
    B1 -- "ドメインデータ" --> B2
    B2 -- "ビジネスロジック" --> B3
  end

  %% "Data層"
  subgraph "Data層"
    C1["Repository実装"]
    C2["DataSource(Firestore/API)"]
    C1 -- "データ取得/保存" --> C2
  end

  %% "外部システム"
  subgraph "外部システム"
    D1["Firestore"]
    D2["Google Cloud Functions"]
    D3["Gemini API"]
    D4["カメラAPI"]
  end

  %% "依存関係"
  A2 -- "UseCase呼び出し/Entity受取" --> B2
  B3 -- "実装依存" --> C1
  C2 -- "REST/SDK通信" --> D1
  C2 -- "REST通信" --> D2
  D2 -- "AIリクエスト/レスポンス" --> D3

  %% "データの流れ"
  A1 -- "ユーザー操作/表示データ" --> A2
  A2 -- "状態データ/イベント" --> A1
  A2 -- "ドメインデータ/ユースケース" --> B2
  B2 -- "エンティティ/DTO" --> A2
  C1 -- "ドメインモデル/DTO" --> B3
  C2 -- "JSON/Mapデータ" --> C1
  D1 -- "ドキュメントデータ" --> C2
  D3 -- "レシピ案JSON" --> D2
```

### 各モジュールの依存関係・データやり取り
- Presentation層（View, ViewModel）はDomain層のUseCase/Entityに依存し、状態やイベントをやり取りします。
- Domain層はRepositoryインターフェースを通じてData層に依存します。
- Data層は外部システム（Firestore, Cloud Functions, Gemini API等）とデータのやり取りを行います。
- データのやり取りは、エンティティ/DTO/Map/JSONなどで行われます。

## ディレクトリ構成

```
/lib
  /presentation (screens, viewmodels, widgets)
  /domain (entities, usecases, repositories)
  /data (datasources, repositories_impl)
  /core (utils, errors)
  main.dart
/test
  ...（各レイヤのテスト）
```
