import vibe.d;
import std.conv;
import std.stdio;
import std.file;
import std.path;
import std.process;
import std.algorithm;

struct Call {
    string bin;
    string[] args;
    string cwd;
}

struct Result {
    int exitCode;
    string text;
}

@path("/")
interface IRpc
{
	Result postCall(Call c);
}

version(server) {

    version(Windows) {
        ushort port = 4321;
    } else {
        ushort port = 4322;
    }

    class Rpc : IRpc {
        Result postCall(Call c) {
            string[] args;
            args ~= c.bin;
            args ~= c.args;

            string cwd = c.cwd;

            cwd = expandTilde(cwd);

            version(Windows) {
                if (cwd.indexOf("/mnt/") == 0) {
                    cwd = cwd.replace("/mnt/", "");
                    auto cwdparts = cwd.split("/");
                    cwd = cwdparts[0] ~ ":/";
                    cwd ~= cwdparts[1..$].join("/");
                } else {
                    if (cwd.indexOf("/home/") == 0) {
                        cwd = buildNormalizedPath(environment["LOCALAPPDATA"], "Lxss/home", cwd[6..$]);
                    } else if (cwd.indexOf("/") == 0) {
                        cwd = cwd[1..$];
                    }
                    cwd = buildNormalizedPath(environment["LOCALAPPDATA"], "Lxss/rootfs", cwd);
                }
            } else {
                string[] cwdparts;
                if (cwd.indexOf(":\\") > 0) {
                    cwdparts = cwd.split(":\\");
                } else if (cwd.indexOf(":/") > 0) {
                    cwdparts = cwd.split(":/");
                }
                cwd = "/mnt/" ~ cwdparts[0].toLower ~ "/" ~ cwdparts[1].replace("\\", "/");
            }

            auto cmd = executeShell(args.join(" "), null, Config.none, size_t.max, cwd);
            Result r;
            r.exitCode = cmd.status;
            r.text = cmd.output;
            return r;
        }
    }

    shared static this()
    {
        auto router = new URLRouter;
	    router.registerRestInterface(new Rpc);
        auto settings = new HTTPServerSettings;
        settings.port = port;
        settings.bindAddresses = ["127.0.0.1"];
        listenHTTP(settings, router);

        logInfo("running");
    }
}

version(client) {
    version(Windows) {
        ushort port = 4322;
    } else {
        ushort port = 4321;
    }

    int main(string[] args) {
        string cwd = "";
        args = args[1..$];

        if (args.length < 1) {
            writeln("no binary given");
            return -98;
        }

        string bin = args[0];
        args = args[1..$];

        if (cwd == "") {
            cwd = getcwd();
        }

        cwd = asAbsolutePath(asNormalizedPath(cwd).array).array.to!string;

        auto client = new RestInterfaceClient!IRpc("http://127.0.0.1:" ~ port.to!string ~ "/");
        Result r = client.postCall(Call(bin, args, cwd));
        writeln(r.text);
        return r.exitCode;
    }
}