using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace ConfigureMe.Setup;

internal static class SetupPlanFile
{
    // Win32 no-follow open plus a read-only sharing lock and final-handle path verification.
    // The caller receives bytes; the original filename is never used by the engine.
    public static byte[] ReadSnapshot(string path)
    {
        if (!OperatingSystem.IsWindows()) throw new PlatformNotSupportedException("Plan file import requires Windows.");
        ValidateLocalPath(path);
        using var handle = CreateFile(path, 0x80000000, 1, IntPtr.Zero, 3, 0x00200000 | 0x08000000, IntPtr.Zero);
        if (handle.IsInvalid) throw new IOException("Die Plandatei konnte nicht exklusiv gegen Änderungen geöffnet werden.", new Win32Exception(Marshal.GetLastWin32Error()));
        var finalName = new StringBuilder(32768);
        var length = GetFinalPathNameByHandle(handle, finalName, (uint)finalName.Capacity, 0);
        if (length == 0 || length >= finalName.Capacity) throw new IOException("Der tatsächliche Planpfad konnte nicht geprüft werden.");
        var actual = finalName.ToString();
        if (actual.StartsWith(@"\\?\", StringComparison.Ordinal)) actual = actual[4..];
        if (!string.Equals(actual, path, StringComparison.OrdinalIgnoreCase))
            throw new IOException("Der Planpfad wurde umgeleitet.");
        if (!GetFileInformationByHandle(handle, out var information) || (information.Attributes & 0x410) != 0)
            throw new IOException("Verzeichnisse und Reparse Points sind als Plandatei nicht erlaubt.");
        ValidateLocalPath(path);
        using var stream = new FileStream(handle, FileAccess.Read);
        if (stream.Length > SetupPlanContract.MaxBytes) throw new InvalidDataException("Der Setup-Plan ist zu groß.");
        var snapshot = new byte[checked((int)stream.Length)];
        stream.ReadExactly(snapshot);
        if (stream.ReadByte() != -1) throw new IOException("Die Plandatei hat sich während des Lesens geändert.");
        return snapshot;
    }

    internal static void ValidateLocalPath(string path)
    {
        if (string.IsNullOrEmpty(path) || path.Length > 4096 || !Path.IsPathFullyQualified(path) ||
            path.Length < 3 || !char.IsAsciiLetter(path[0]) || path[1] != ':' || path[2] != '\\' ||
            path[2..].Contains(':') || !string.Equals(Path.GetFullPath(path), path, StringComparison.OrdinalIgnoreCase))
            throw new IOException("Bitte einen absoluten lokalen Planpfad ohne UNC-/Gerätepfad oder Datenstrom wählen.");
        if (new DriveInfo(path[..3]).DriveType != DriveType.Fixed)
            throw new IOException("Die Plandatei muss auf einem lokalen festen Laufwerk liegen.");
        EngineBundle.ValidatePath(path);
        if (!File.Exists(path)) throw new FileNotFoundException("Die Plandatei fehlt.");
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct FileInformation
    {
        public uint Attributes;
        public System.Runtime.InteropServices.ComTypes.FILETIME CreationTime, LastAccessTime, LastWriteTime;
        public uint VolumeSerialNumber, FileSizeHigh, FileSizeLow, NumberOfLinks, FileIndexHigh, FileIndexLow;
    }
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern SafeFileHandle CreateFile(string name, uint access, uint share, IntPtr security,
        uint disposition, uint flags, IntPtr template);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern uint GetFinalPathNameByHandle(SafeFileHandle file, StringBuilder path, uint length, uint flags);
    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetFileInformationByHandle(SafeFileHandle file, out FileInformation information);
}
