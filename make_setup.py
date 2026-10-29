import os
import zipfile
import subprocess

release_dir = r'c:\Users\Eskander\Desktop\rapport_essai_app\build\windows\x64\runner\Release'
output_installer_dir = r'c:\Users\Eskander\Desktop\rapport_essai_app\build\installer'
os.makedirs(output_installer_dir, exist_ok=True)

# 1. Create temp_app.zip
zip_path = os.path.join(output_installer_dir, 'temp_app.zip')
with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
    for root, dirs, files in os.walk(release_dir):
        for file in files:
            full_path = os.path.join(root, file)
            rel_path = os.path.relpath(full_path, release_dir)
            zipf.write(full_path, rel_path)

print('Created temp_app.zip:', zip_path, 'Size:', os.path.getsize(zip_path))

# 2. Write clean C# installer code
cs_code = '''using System;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Diagnostics;
using System.Windows.Forms;

namespace MacrographiqueInstaller
{
    static class Program
    {
        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            string targetDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Macrographique");

            try
            {
                if (!Directory.Exists(targetDir))
                {
                    Directory.CreateDirectory(targetDir);
                }

                Assembly assembly = Assembly.GetExecutingAssembly();
                using (Stream stream = assembly.GetManifestResourceStream("app.zip"))
                {
                    if (stream != null)
                    {
                        using (ZipArchive archive = new ZipArchive(stream))
                        {
                            foreach (ZipArchiveEntry entry in archive.Entries)
                            {
                                string destinationPath = Path.Combine(targetDir, entry.FullName);
                                string dirPath = Path.GetDirectoryName(destinationPath);
                                if (!Directory.Exists(dirPath))
                                {
                                    Directory.CreateDirectory(dirPath);
                                }
                                if (!string.IsNullOrEmpty(entry.Name))
                                {
                                    try
                                    {
                                        entry.ExtractToFile(destinationPath, true);
                                    }
                                    catch { }
                                }
                            }
                        }
                    }
                }

                string exePath = Path.Combine(targetDir, "macrographique.exe");
                string desktopPath = Environment.GetFolderPath(Environment.SpecialFolder.Desktop);
                string lnkPath = Path.Combine(desktopPath, "Macrographique.lnk");

                try
                {
                    Type shellType = Type.GetTypeFromProgID("WScript.Shell");
                    dynamic shell = Activator.CreateInstance(shellType);
                    dynamic shortcut = shell.CreateShortcut(lnkPath);
                    shortcut.TargetPath = exePath;
                    shortcut.WorkingDirectory = targetDir;
                    shortcut.IconLocation = exePath + ",0";
                    shortcut.Save();
                }
                catch { }

                ProcessStartInfo startInfo = new ProcessStartInfo(exePath)
                {
                    WorkingDirectory = targetDir,
                    UseShellExecute = true
                };
                Process.Start(startInfo);

                MessageBox.Show("Installation de Macrographique terminée avec succès !\\nLe raccourci a été créé sur votre Bureau.", "Macrographique Setup", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
            catch (Exception ex)
            {
                MessageBox.Show("Erreur lors de l'installation : " + ex.Message, "Erreur Setup", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }
    }
}
'''

cs_file = os.path.join(output_installer_dir, 'Installer.cs')
with open(cs_file, 'w', encoding='utf-8') as f:
    f.write(cs_code)

# 3. Compile with csc.exe
csc_exe = r'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'
ico_file = r'c:\Users\Eskander\Desktop\rapport_essai_app\windows\runner\resources\app_icon.ico'
out_exe = os.path.join(output_installer_dir, 'Setup_Macrographique.exe')

cmd = [
    csc_exe,
    '/target:winexe',
    f'/out:{out_exe}',
    f'/win32icon:{ico_file}',
    f'/resource:{zip_path},app.zip',
    '/r:System.Windows.Forms.dll',
    '/r:System.IO.Compression.dll',
    '/r:System.IO.Compression.FileSystem.dll',
    '/r:Microsoft.CSharp.dll',
    cs_file
]

res = subprocess.run(cmd, capture_output=True, text=True)
print('CSC Return Code:', res.returncode)
print('CSC Output:', res.stdout)
print('CSC Errors:', res.stderr)

if os.path.exists(out_exe):
    print('Generated Setup_Macrographique.exe successfully!', 'Size:', os.path.getsize(out_exe))

# Clean temp zip & cs
for f in [zip_path, cs_file]:
    if os.path.exists(f):
        os.remove(f)
