import os from "os";
import * as nodepty from "node-pty";

const shell = os.platform() === "win32" ? "powershell.exe" : "bash";

/**
 * 1. Create a new user in the system
 * sudo useradd -d /home/test_user test_user
 * 
 * 2. Get the UID and GID of the user
 * id test_user
 * 
 * 3. Set the environment variables
 */

export class PTY {
  ptyProcess: nodepty.IPty;
  history: string = "";

  constructor() {
    this.ptyProcess = nodepty.spawn(shell, [], {
      name: "xterm-color",
      cols: 80,
      rows: 30,
      cwd: process.env.PROCESS_HOME,
      env: process.env,
      // gid: parseInt(process.env.PROCESS_GID),
      uid: parseInt(process.env.PROCESS_UID),
    });

    this.ptyProcess.onData((data) => {
      this.history += data;
    });
  }
}
