const { mkdirSync } = require("fs")
const { existsSync } = require("fs")
const { readFileSync } = require("fs")
const { execSync } = require("child_process")
if (!existsSync("repositories-directory")) {
    mkdirSync("repositories-directory")
}
if (!existsSync("binaries-directory")) {
    mkdirSync("binaries-directory")
}
execSync("sudo apt update && sudo apt upgrade --yes", { stdio: "inherit" })
execSync("sudo apt --fix-broken install --yes", { stdio: "inherit" })
execSync("sudo apt-get install make wget git --yes", { stdio: "inherit" })
const programs = JSON.parse(readFileSync("programs.json"))
const alreadyInstalled = []
for (const program of programs) {
    install(program)
}

function install(program) {
    if (alreadyInstalled.includes(program.name))
        return
    if (program.dependencies) {
        for (const dependency of program.dependencies) {
            install(programs.filter(value => value.name === dependency)[0])
        }
    }
    switch (program.installationType) {
        case "apt":
            try {
                execSync(`sudo apt-get install ${program.name} --yes`, { stdio: "inherit" })
            } catch (error) {
                console.log("oh nooo there was an error, guess what? I don't give a fuck stupid node js")
            }
            break
        case "wget":
            const outputDocument = `./binaries-directory/${program.name}.deb`
            execSync(`sudo wget "${program.url}" --output-document=${outputDocument}`, { stdio: "inherit" })
            execSync(`sudo apt install ${outputDocument} --yes`, { stdio: "inherit" })
            break
        case "git":
            const directory = `repositories-directory/${program.name}`
            try {
                execSync(`git clone "${program.url}" ${directory}`, { stdio: "inherit" })
            } catch (error) {
                console.log("oh nooo there was an error, guess what? I don't give a fuck stupid node js")
            }
            execSync(`make --directory=${directory}`, { stdio: "inherit" })
            execSync(`sudo make install --directory=${directory}`, { stdio: "inherit" })
            break
        default:
            switch (program.name) {
                case "libxft-bgra":
                    // https://www.reddit.com/r/suckless/comments/l3a2yg/comment/god0dbe/?utm_source=share&utm_medium=web2x&context=3
                    const directory = `repositories-directory/${program.name}`
                    execSync(`sudo apt remove libxft2 --yes`, { stdio: "inherit" })
                    try {
                        execSync(`git clone ${program.url} ${directory}`, { stdio: "inherit" })
                    } catch (error) {
                        console.log("oh nooo there was an error, guess what? I don't give a fuck stupid node js")
                    }
                    execSync(`cd ${directory}; sh autogen.sh --sysconfdir=/etc --prefix=/usr --mandir=/usr/share/man; sudo make install clean`, { stdio: "inherit" })
                    break;
                // case "docker":
                //     // Add Docker’s official GPG key:
                //     execSync(`sudo mkdir "/etc/apt/keyrings" --parents`, { stdio: "inherit" })
                //     execSync(`curl "https://download.docker.com/linux/debian/gpg" --fail --silent --location| sudo gpg --dearmor -o "/etc/apt/keyrings/docker.gpg"`, { stdio: "inherit" })
                //     execSync(`sudo chmod a+r "/etc/apt/keyrings/docker.gpg"`, { stdio: "inherit" })
                //     // Setup a repository
                //     execSync(`echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee "/etc/apt/sources.list.d/docker.list" > /dev/null`, { stdio: "inherit" })
                //     // Install docker engine
                //     execSync(`sudo apt-get update`, { stdio: "inherit" })
                //     execSync(`sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin`, { stdio: "inherit" })
                //     break;
                default:
                    break;
            }
            break

    }
    alreadyInstalled.push(program.name)
}
