# TlsClientLib
TlsClientLib is a TLS client library for OMRON's NX series.
The TLS client (TlsClient) in this library reads and writes TLS send/receive data to a buffer passed as a parameter.
The buffer utilizes RingBufferLib.
[RingBufferLib](https://github.com/kmu2030/RingBufferLib) is an implementation of a ring buffer for BYTE type arrays.
The RingBufferLib implementation can be used in multi-tasking environments without locks, provided there is only one entity for reading and one for writing to the buffer.
TlsClient inherits this characteristic.
Furthermore, it can be flexibly combined with other programs that use RingBufferLib as their buffer.

The example below demonstrates combining TlsClient with a simple Logger that uses RingBufferLib as its buffer to send logs to a remote TLS endpoint.

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
````

This program does not directly read log data from the Logger's buffer; instead, it tracks writes to the Logger's buffer and sends logs remotely.
This allows for remote log transmission while minimizing coupling between the Logger and TlsClient.
Of course, TlsClient can also be used as a consumer of the Logger's log data.
To use TlsClient as a consumer, simply specify the Logger's buffer as TlsClient's send buffer.

The functionality of TlsClient heavily relies on RingBufferLib, which aids in streaming data processing.
However, RingBufferLib does not possess any special mechanisms to achieve such functionality.
It is implemented solely using information required for the behavior of a ring buffer.
Therefore, even if RingBufferLib were to become unusable, anyone could re-implement it.

## Operating Environment
The following environment is required to use this project.

| Item           | Requirement |
| :------------- | :---------- |
| Controller     | NX or NJ    |
| Sysmac Studio  | Latest recommended |

## Development Environment
This project was developed in the following environment.

| Item               | Version                  |
| :----------------- | :----------------------- |
| Controller         | NX102-9000 Ver 1.64      |
| Sysmac Studio      | Ver.1.62                 |

## How to Use the Library
Use the library (`TlsClientLib.slr`) by following these steps.

1.  **Reference `lib/RingBufferLib.slr` in your project.**

2.  **Reference `TlsClientLib.slr` in your project.**

3.  **Build the project and confirm there are no errors.**   
    Both libraries use namespaces.   
    Ensure that there are no identifier conflicts with namespaces within your project.

## How to Use the Example Program
The Sysmac project (`TlsClientLib.smc2`) includes an example program and can be used by following these steps.

1.  **Adjust the project configuration to match your operating environment.**   
    Match the controller model and ensure access to the network you intend to use.
  
2.  **Adjust `POU/Program/Example_SendLog` to match your operating environment.**   
    Change the value of the `REMOTE_ADDR` variable to the address of the device waiting for data.

3.  **Start TLS endpoints on an appropriate device and wait for connections.**   
    You can find a reference PowerShell script in `POU/Program/SimpleTlsMonitor_ps1`.   
	`StartMultiMonitors_ps1` is a PowerShell script that uses Windows Terminal to launch four TLS endpoints.

4.  **Register TLS sessions on the controller.**   
    Register four TLS sessions with IDs 0-3.

5.  **Run the program on the controller.**   
    Transfer the program to the controller and start its execution.

6.  **Confirm that data is sent to the listening TLS endpoints.**
