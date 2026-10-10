// DiverExportAnalysis.java -- headless export for diver's security.ghidra.
//
// Bundled with the Neovim config and run by analyzeHeadless as a
// -postScript. Writes three bounded files into the directory named by
// script argument 1:
//
//   functions.tsv  address <TAB> name <TAB> signature
//   strings.tsv    address <TAB> value (control characters escaped)
//   decompile.c    decompiled C per function, total bytes bounded
//
// The caps here mirror lua/security/ghidra.lua: the export stays small no
// matter how large the analyzed binary is. Written against Ghidra's
// long-stable script API (the same calls its bundled Decompile script
// uses); requires no network and writes nowhere outside the export dir.
//
//@category Diver

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileWriter;

import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.Data;
import ghidra.program.model.listing.DataIterator;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionIterator;

public class DiverExportAnalysis extends GhidraScript {

    private static final int FUNCTION_MAX = 5000;
    private static final int STRING_MAX = 5000;
    private static final int STRING_CHARS_MAX = 200;
    private static final long DECOMPILE_BYTES_MAX = 4L * 1024L * 1024L;
    private static final int DECOMPILE_TIMEOUT_S = 30;

    @Override
    public void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length < 1) {
            printerr("DiverExportAnalysis: export directory argument missing");
            return;
        }
        File outDir = new File(args[0]);
        if (!outDir.exists() && !outDir.mkdirs()) {
            printerr("DiverExportAnalysis: cannot create export dir " + args[0]);
            return;
        }
        exportFunctions(new File(outDir, "functions.tsv"));
        exportStrings(new File(outDir, "strings.tsv"));
        exportDecompile(new File(outDir, "decompile.c"));
    }

    private void exportFunctions(File outFile) throws Exception {
        try (BufferedWriter writer = new BufferedWriter(new FileWriter(outFile))) {
            FunctionIterator functions = currentProgram.getFunctionManager().getFunctions(true);
            int count = 0;
            while (functions.hasNext() && count < FUNCTION_MAX) {
                if (monitor.isCancelled()) {
                    break;
                }
                Function fn = functions.next();
                writer.write(fn.getEntryPoint().toString());
                writer.write('\t');
                writer.write(flatten(fn.getName()));
                writer.write('\t');
                writer.write(flatten(fn.getSignature().toString()));
                writer.newLine();
                count++;
            }
        }
    }

    private void exportStrings(File outFile) throws Exception {
        try (BufferedWriter writer = new BufferedWriter(new FileWriter(outFile))) {
            DataIterator dataItems = currentProgram.getListing().getDefinedData(true);
            int count = 0;
            while (dataItems.hasNext() && count < STRING_MAX) {
                if (monitor.isCancelled()) {
                    break;
                }
                Data data = dataItems.next();
                Object value = data.getValue();
                if (value instanceof String) {
                    writer.write(data.getAddress().toString());
                    writer.write('\t');
                    writer.write(escape((String) value));
                    writer.newLine();
                    count++;
                }
            }
        }
    }

    private void exportDecompile(File outFile) throws Exception {
        try (BufferedWriter writer = new BufferedWriter(new FileWriter(outFile))) {
            DecompInterface decompiler = new DecompInterface();
            decompiler.toggleCCode(true);
            if (!decompiler.openProgram(currentProgram)) {
                writer.write("// DiverExportAnalysis: decompiler failed to open the program\n");
                return;
            }
            try {
                FunctionIterator functions =
                    currentProgram.getFunctionManager().getFunctions(true);
                long bytes = 0;
                while (functions.hasNext() && bytes < DECOMPILE_BYTES_MAX) {
                    if (monitor.isCancelled()) {
                        break;
                    }
                    Function fn = functions.next();
                    DecompileResults results =
                        decompiler.decompileFunction(fn, DECOMPILE_TIMEOUT_S, monitor);
                    if (results != null && results.decompileCompleted()
                        && results.getDecompiledFunction() != null) {
                        String chunk = "// ---- " + fn.getEntryPoint() + ' ' + fn.getName()
                            + " ----\n" + results.getDecompiledFunction().getC() + '\n';
                        writer.write(chunk);
                        bytes += chunk.length();
                    }
                }
            } finally {
                decompiler.dispose();
            }
        }
    }

    // Tab-separated output cannot carry raw tabs or newlines inside a field.
    private static String flatten(String text) {
        return text.replace('\t', ' ').replace('\n', ' ').replace('\r', ' ');
    }

    private static String escape(String text) {
        String trimmed = text.length() > STRING_CHARS_MAX
            ? text.substring(0, STRING_CHARS_MAX)
            : text;
        StringBuilder out = new StringBuilder(trimmed.length());
        for (int i = 0; i < trimmed.length(); i++) {
            char c = trimmed.charAt(i);
            switch (c) {
                case '\t':
                    out.append("\\t");
                    break;
                case '\n':
                    out.append("\\n");
                    break;
                case '\r':
                    out.append("\\r");
                    break;
                case '\\':
                    out.append("\\\\");
                    break;
                default:
                    out.append(c);
            }
        }
        return out.toString();
    }
}
