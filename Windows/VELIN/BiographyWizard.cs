using Velin.Core;
namespace Velin.Windows;

internal sealed class BiographyWizard : Form
{
    public string BiographyText { get; private set; } = "";
    public BiographyWizard(string existing) { Text = "A little about you · VELIN"; Size = new Size(500, 600); MinimumSize = Size; StartPosition = FormStartPosition.CenterParent; BackColor = Theme.Background; ForeColor = Color.White; Font = Theme.Font(); var flow = Theme.Column(); Controls.Add(flow); flow.Controls.Add(new WrappedLabel { Text = "Fill in only what you want to share. This local builder uses your facts; no AI request or invented experience.", Width = 430 }); List<TextBox> fields = []; foreach (var label in new[] { "Name / preferred name", "Skills", "Education / highest qualification", "Experience and projects", "Goals", "Age · optional" }) { flow.Controls.Add(Theme.Label(label, 9, Theme.Muted)); var field = Theme.Input(); field.Width = 420; fields.Add(field); flow.Controls.Add(field); } flow.Controls.Add(new ClickButton(existing.Length > 0 ? "Replace About me" : "Use introduction", () => { BiographyText = Biography.Compose(fields[0].Text, fields[1].Text, fields[2].Text, fields[3].Text, fields[4].Text, fields[5].Text); if (BiographyText.Length == 0) return; DialogResult = DialogResult.OK; Close(); }, true)); }
}
