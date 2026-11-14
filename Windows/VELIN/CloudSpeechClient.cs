using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using System.Threading.Channels;
using Velin.Core;
namespace Velin.Windows;

internal sealed class CloudSpeechClient:IDisposable
{
    readonly ClientWebSocket socket=new();readonly CancellationTokenSource stop=new();readonly HttpMessageInvoker transport=new(new SocketsHttpHandler{AllowAutoRedirect=false});
    readonly Channel<(byte[] Data,WebSocketMessageType Type)> queue=Channel.CreateBounded<(byte[],WebSocketMessageType)>(32);
    readonly Action<string,bool> result;readonly Action<string> warning;readonly SonioxTranscript transcript=new();int disposed;
    public CloudSpeechClient(string key,Action<string,bool> result,Action<string> warning)
    {
        this.result=result;this.warning=warning;
        if(string.IsNullOrWhiteSpace(key)||key.Contains('\r')||key.Contains('\n'))throw new IOException("Save a valid Soniox speech API key first.");
        socket.Options.SetRequestHeader("Authorization","Bearer "+key);
        try{using var timeout=new CancellationTokenSource(TimeSpan.FromSeconds(20));socket.ConnectAsync(new Uri(SonioxProtocol.Endpoint),transport,timeout.Token).GetAwaiter().GetResult();socket.SendAsync(Encoding.UTF8.GetBytes(SonioxProtocol.Configuration),WebSocketMessageType.Text,true,timeout.Token).GetAwaiter().GetResult();}
        catch{Dispose();throw new IOException("Soniox connection failed. Check the speech API key, network and service availability.");}
        _=Task.Run(Send);_=Task.Run(Receive);_=Task.Run(Keepalive);
    }
    public void Feed(byte[] data,int count){if(Volatile.Read(ref disposed)!=0)return;var bytes=data.AsSpan(0,count).ToArray();if(!queue.Writer.TryWrite((bytes,WebSocketMessageType.Binary)))Fail("Cloud speech could not keep up with the network. Restart this audio control.");}
    async Task Send(){try{await foreach(var item in queue.Reader.ReadAllAsync(stop.Token))await socket.SendAsync(item.Data,item.Type,true,stop.Token);}catch(OperationCanceledException){}catch{Fail("Soniox audio stream disconnected. Restart this control to retry.");}}
    async Task Keepalive(){try{using var timer=new PeriodicTimer(TimeSpan.FromSeconds(8));while(await timer.WaitForNextTickAsync(stop.Token))if(!queue.Writer.TryWrite((Encoding.UTF8.GetBytes("{\"type\":\"keepalive\"}"),WebSocketMessageType.Text)))Fail("Cloud speech is falling behind. Restart this control.");}catch(OperationCanceledException){}}
    async Task Receive(){try{var buffer=new byte[65536];while(!stop.IsCancellationRequested){using var message=new MemoryStream();WebSocketReceiveResult frame;do{frame=await socket.ReceiveAsync(new ArraySegment<byte>(buffer),stop.Token);if(frame.MessageType==WebSocketMessageType.Close)throw new IOException();message.Write(buffer,0,frame.Count);if(message.Length>65536)throw new IOException();}while(!frame.EndOfMessage);using var doc=JsonDocument.Parse(message.ToArray());foreach(var text in transcript.Accept(doc.RootElement))result(text,true);result(transcript.Preview,false);if(doc.RootElement.TryGetProperty("finished",out var done)&&done.GetBoolean()){Fail("Soniox ended the session. Restart this audio control to continue.");return;}}}catch(OperationCanceledException){}catch{Fail("Soniox transcription disconnected. Check the speech key, credits and network.");}}
    void Fail(string text){if(Volatile.Read(ref disposed)!=0)return;Dispose();warning(text);}
    public void Dispose(){if(Interlocked.Exchange(ref disposed,1)!=0)return;stop.Cancel();queue.Writer.TryComplete();socket.Abort();socket.Dispose();transport.Dispose();}
}
