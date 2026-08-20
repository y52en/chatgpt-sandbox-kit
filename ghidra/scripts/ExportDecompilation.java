// Export all decompilable functions from the current program to one text file.
// @category Sandbox

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileWriter;
import java.io.PrintWriter;

import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionIterator;

public class ExportDecompilation extends GhidraScript {
    private static final int TIMEOUT_SECONDS = 60;

    @Override
    public void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length != 1) {
            throw new IllegalArgumentException("usage: ExportDecompilation.java OUTPUT_FILE");
        }

        File output = new File(args[0]).getCanonicalFile();
        File parent = output.getParentFile();
        if (parent != null && !parent.exists() && !parent.mkdirs()) {
            throw new IllegalStateException("failed to create output directory: " + parent);
        }

        DecompInterface decompiler = new DecompInterface();
        decompiler.toggleCCode(true);
        decompiler.toggleSyntaxTree(true);
        if (!decompiler.openProgram(currentProgram)) {
            throw new IllegalStateException("failed to initialize Ghidra decompiler");
        }

        int succeeded = 0;
        int failed = 0;
        try (PrintWriter out = new PrintWriter(new BufferedWriter(new FileWriter(output)))) {
            out.printf("/* Program: %s */%n", currentProgram.getName());
            out.printf("/* Language: %s */%n%n", currentProgram.getLanguageID());

            FunctionIterator functions = currentProgram.getFunctionManager().getFunctions(true);
            while (functions.hasNext() && !monitor.isCancelled()) {
                Function function = functions.next();
                monitor.setMessage("Decompiling " + function.getName());
                DecompileResults result = decompiler.decompileFunction(function, TIMEOUT_SECONDS, monitor);

                out.printf("/* ==== %s @ %s ==== */%n", function.getName(), function.getEntryPoint());
                if (result.decompileCompleted() && result.getDecompiledFunction() != null) {
                    out.println(result.getDecompiledFunction().getC());
                    succeeded++;
                }
                else {
                    String error = result.getErrorMessage();
                    out.printf("/* decompilation failed%s */%n%n",
                        error == null || error.isBlank() ? "" : ": " + error.replace("*/", "* /"));
                    failed++;
                }
            }
        }
        finally {
            decompiler.dispose();
        }

        println("Exported decompilation to " + output);
        println("Functions: " + succeeded + " succeeded, " + failed + " failed");
        if (succeeded == 0) {
            throw new IllegalStateException("no functions were successfully decompiled");
        }
    }
}
