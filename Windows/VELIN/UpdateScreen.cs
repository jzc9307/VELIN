using System.Drawing.Drawing2D;
namespace Velin.Windows;

internal sealed class UpdateScreen:UserControl
{
    readonly AppUpdates updates;readonly System.Windows.Forms.Timer timer=new(){Interval=33};readonly ClickButton cancel;
    double angle;
    public UpdateScreen(AppUpdates updates)
    {
        this.updates=updates;Dock=DockStyle.Fill;BackColor=Theme.Background;DoubleBuffered=true;
        SetStyle(ControlStyles.AllPaintingInWmPaint|ControlStyles.UserPaint|ControlStyles.OptimizedDoubleBuffer,true);
        cancel=new ClickButton("Continue to VELIN",()=>{if(updates.Launching)updates.SkipLaunch();else if(updates.Downloading)updates.Cancel();else updates.Dismiss();});Controls.Add(cancel);
        timer.Tick+=(_,_)=>{angle=(angle+4)%360;Invalidate();};timer.Start();VisibleChanged+=(_,_)=>{if(Visible&&SystemInformation.IsMenuAnimationEnabled)timer.Start();else timer.Stop();};Resize+=(_,_)=>Place();updates.Changed+=UpdateState;UpdateState();
    }
    void Place(){cancel.SetBounds((Width-180)/2,Math.Max(360,Height/2+(updates.Failure!=null?195:165)),180,36);}
    void UpdateState(){if(IsDisposed)return;cancel.Text=updates.Launching?"Continue to VELIN":updates.Downloading?"Cancel download":"Back to VELIN";Place();Invalidate();}
    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);var g=e.Graphics;g.SmoothingMode=SmoothingMode.AntiAlias;float cx=Width/2f,cy=Math.Max(130,Height/2f-100);
        using var ring=new Pen(Color.FromArgb(32,Theme.Mint),1);g.DrawEllipse(ring,cx-65,cy-65,130,130);using var arc=new Pen(Theme.Mint,3){StartCap=LineCap.Round,EndCap=LineCap.Round};g.DrawArc(arc,cx-65,cy-65,130,130,(float)angle,110);
        using var left=new Pen(Theme.Mint,8){StartCap=LineCap.Round,EndCap=LineCap.Round};using var right=new Pen(Theme.Lilac,8){StartCap=LineCap.Round,EndCap=LineCap.Round};g.DrawBezier(left,cx-25,cy-24,cx-24,cy,cx-12,cy+22,cx,cy+28);g.DrawBezier(right,cx,cy+28,cx+7,cy+6,cx+22,cy-23,cx+29,cy-28);
        using var dot=new SolidBrush(Theme.Mint);g.FillEllipse(dot,cx-3,cy-31,5,5);
        void Text(string text,int size,Color color,float y,float height=70){using var font=Theme.Font(size);using var brush=new SolidBrush(color);using var format=new StringFormat{Alignment=StringAlignment.Center};g.DrawString(text,font,brush,new RectangleF(30,y,Width-60,height),format);}
        Text(updates.Launching?"V E L I N":"A little upgrade. More clarity.",24,Color.White,cy+90);
        Text(updates.Launching?"Finding your latest version…":updates.Status,12,Theme.Muted,cy+137);
        if(!updates.Launching){var bar=new RectangleF(cx-170,cy+188,340,5);using var muted=new SolidBrush(Color.FromArgb(40,Color.White));g.FillRectangle(muted,bar);g.FillRectangle(dot,bar.X,bar.Y,(float)(bar.Width*Math.Clamp(updates.Progress,0,1)),bar.Height);Text($"{updates.Progress:P0} · Your keys, settings and conversations stay here",10,Theme.Muted,cy+209);}
        if(updates.Failure!=null&&!updates.Launching)Text(updates.Failure,10,Theme.Lilac,cy+235,44);
        Text("Public GitHub Releases · no account needed",9,Theme.Muted,Height-40);
    }
    protected override void Dispose(bool disposing){if(disposing){timer.Dispose();updates.Changed-=UpdateState;}base.Dispose(disposing);}
}
