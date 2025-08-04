# TlsClientLib
TlsClientLibは、OMRON社のNX向けのTLSクライアントライブラリです。
このライブラリのTLSクライアント(TlsClient)は、パラメータとして渡したバッファに対してTLSによる送受信データを読み書きします。
バッファは、RingBufferLibを使用します。
[RingBufferLib](https://github.com/kmu2030/RingBufferLib)はBYTE型配列を対象とするリングバッファの実装です。
RingBufferLibの実装は、バッファへの読み書きの主体がそれぞれ1つである時に限り、ロックを使用しなくてもマルチタスクに使用することができます。
TlsClientはその特性を引き継ぎます。
また、バッファとしてRingBufferLibを使用する他のプログラムと柔軟に組み合わせることができます。

以下は、バッファとしてRingBufferLibを使用する素朴なLoggerにTlsClientを組み合わせ、ログをリモートのTLSエンドポイントに送信します。

```iecst
IF P_First_Run THEN
    REMOTE_ADDR := 'YOUR_REMOTE_DEVICE';
    REMOTE_PORT := 12101;
    LOGGING_INTERVAL := 1;
END_IF;

IF P_First_Run THEN    
    // Setup Logger.
    Logger_init(Context:=iLoggerBufferContext,
                Buffer:=iLoggerBuffer);    

    // Setup Log sender.
    //
    // The log sender monitors the logger buffer and sends the written logs.
    //
    RingBuffer_init(Context:=iLogSenderSendBufferContext,
                    Buffer:=iLogSenderSendBuffer);
    RingBuffer_init(Context:=iLogSenderRecvBufferContext,
                    Buffer:=iLogSenderRecvBuffer);
    TlsClient_configure(Context:=iLogSenderContext,
                        Activate:=TRUE,
                        Destination:=REMOTE_ADDR,
                        DestinationPort:=REMOTE_PORT,
                        Port:=0,
                        TLSSessionName:='TLSSession0',
                        UseSend:=TRUE,
                        UseRecv:=FALSE,
                        UseWatcher:=TRUE,
                        WatchInterval:=600,
                        ConnectRetryTimes:=100,
                        ConnectRetryInterval:=600);
    iLogSenderTlsClient.Enable := TRUE;
    // Tracks logger writes.
    RingBuffer_createWriteTracker(Target:=iLoggerBufferContext,
                                  Tracker=>iLoggerWrittenTracker);

    iWaitTick := LOGGING_INTERVAL;
END_IF;

// Logging at regular intervals.
Dec(iWaitTick);
IF iWaitTick < 1 THEN
    iMsg := CONCAT('{"counter":', ULINT_TO_STRING(Get1usCnt()),
                   ',"timestamp":"', DtToString(GetTime()),
                   '"}$L');
    Logger_write(Context:=iLoggerBufferContext,
                 Buffer:=iLoggerBuffer,
                 Message:=iMsg);
    
    iWaitTick := LOGGING_INTERVAL;
END_IF;

// Gets the difference of the logger buffer into the log sender's send buffer.
RingBuffer_pullWrite(Context:=iLogSenderSendBufferContext,
                     Buffer:=iLogSenderSendBuffer,
                     Tracker:=iLoggerWrittenTracker,
                     Tracked:=iLoggerBufferContext,
                     TrackedBuffer:=iLoggerBuffer);
iLogSenderTlsClient(Context:=iLogSenderContext,
                    SendBufferContext:=iLogSenderSendBufferContext,
                    SendBuffer:=iLogSenderSendBuffer,
                    RecvBufferContext:=iLogSenderRecvBufferContext,
                    RecvBuffer:=iLogSenderRecvBuffer);
```

このプログラムは、Loggerのバッファから直接ログデータを読み出すのではなく、Loggerのバッファへの書き込みを追跡してリモートにログを送信します。
これにより、LoggerとTlsClientの結合を抑制しながらリモートへのログ送信が可能となります。
TlsClientをLoggerのログデータのコンシューマとすることもできます。
TlsClientをコンシューマとするには、TlsClientの送信バッファとしてLoggerのバッファを指定します。

TlsClientの機能は、ストリーミングデータ処理を支援するRingBufferLibに多分に依存しています。
しかしながら、RingBufferLibはこのような機能を実現するために、特別な機構を有しているわけではありません。
リングバッファの振る舞いに必要とする情報だけから実現しています。
そのため、仮にRingBufferLibが使用できなくなったとしても、それを再実装することは誰にでも可能です。

## 使用環境
このプロジェクトの使用には、以下の環境が必要です。

| Item          | Requirement |
| :------------ | :---------- |
| コントローラ   | NX or NJ    |
| Sysmac Studio | 最新版を推奨 |

## 構築環境
このプロジェクトは、以下の環境で構築しています。

| Item            | Version              |
| :-------------- | :------------------- |
| コントローラ     | NX102-9000 Ver 1.64  |
| Sysmac Studio   | Ver.1.62             |

## ライブラリの使用手順
ライブラリ(`TlsClientLib.slr`)は以下の手順で使用します。

1.  **`lib/RingBufferLib.slr`をプロジェクトで参照する**

2.  **`TlsClientLib.slr`をプロジェクトで参照する**

3.  **プロジェクトをビルドしてエラーが無いことを確認する**   
    いずれのライブラリも名前空間を使用しています。   
    プロジェクト内の識別子と名前空間の衝突が生じていないことを確認します。

## 例示プログラムの使用手順
Sysmacプロジェクト(`TlsClientLib.smc2`)は例示プログラムを含み、以下の手順で使用します。

1.  **プロジェクトの構成を使用環境に合わせる**   
    コントローラの型式を合わせ、使用するネットワークにアクセスできるようにします。
  
2.  **`POU/プログラム/Example_SendLog`を使用環境に合わせる**   
    `REMOTE_ADDR`変数の値をデータを待ち受ける端末のアドレスに変更します。
  
3.  **適当な端末にTLSエンドポイントを立ち上げ待ち受ける**   
    `POU/プログラム/SimpleTlsMonitor_ps1`に参考のPowerShellスクリプトがあります。   
	`StartMultiMonitors_ps1`は、Windows Terminalを使用して4つのTLSエンドポイントを立ち上げるPowerShellスクリプトです。

4.  **コントローラにTLSセッションを登録する**   
    4つのTLSセッションをID 0-3で登録します。

5.  **コントローラでプログラムを動作させる**   
    プログラムをコントローラに転送して動作させます。
  
6.  **待ち受けているTLSエンドポイントにデータが送られてくることを確認する**
