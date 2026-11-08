// Compatibility surface retained from the bundled Bio.cs 2.5 library.
// Keep the field's option metadata: callers may inspect it through reflection.
using System;

namespace BioLib.CLI {
    [AttributeUsage(AttributeTargets.Field)]
    internal class OptionAttribute : Attribute {
        public string Name { get; set; }
        public string Description { get; set; }
    }

    /// <summary>Legacy command-line options retained for existing callers.</summary>
    public class DefaultOptions {
        /// <summary>Whether the caller requested help; initially false.</summary>
        [Option(Name = "h", Description = "Show help message")]
        public bool help;
    }
}
