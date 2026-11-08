using System;
using System.IO;
using BioLib;
using BioLib.CLI;
using BioLib.Streams;

// Compile against shipped 2.5, then run the same EXE with each DLL.
class LegacyClient {
    static int Main(string[] args) {
        var options = new DefaultOptions();
        if (options.help) throw new Exception("help should default to false");
        options.help = true;
        if (!options.help) throw new Exception("help must be writable");
        var attrs = typeof(DefaultOptions).GetField("help").GetCustomAttributes(false);
        bool matched = false;
        foreach (var attr in attrs) {
            var type = attr.GetType();
            if (type.FullName != "BioLib.CLI.OptionAttribute") continue;
            matched = (string)type.GetProperty("Name").GetValue(attr, null) == "h"
                && (string)type.GetProperty("Description").GetValue(attr, null) == "Show help message";
        }
        if (!matched) throw new Exception("help metadata changed");
        File.WriteAllBytes(args[0], new byte[] { 3, 65, 66, 67 });
        using (var stream = Bio.FileOpen(args[0], FileMode.Open))
        using (var reader = new BinaryReader(stream)) {
            if (reader.Read8BitPrefixedString(true) != "ABC") throw new Exception("legacy reader changed");
        }
        Console.WriteLine("LEGACY-CLIENT-PASSED");
        return 0;
    }
}
