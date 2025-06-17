# PJ the ProJect Switcher

## Usage

Just clone and source in your bashrc

```bash
# ~/.bashrc
source "$HOME/usrapps/pj/main.sh"
```

It will create a file at `~/.local/share/pj/projects.txt` and register two
functions `pj` and `av` _activate-virtualenv_ and then you can `pj -h`
to see usage information.

**Essentially**

`pj -a` to add the current dir as a new project

`pj myproj` to switch to myproj

or

`pj` to select a project with fzf

Simples, never worry about activating virtualenvs or switching projects again!
It even offers tab completion, partial project name matching and bonus flag

`pj -u` to check all listed projects for unpushed commits

> note:
>
> It is geared towards python projects, and will auto
> activate virtualenvs when switching projects.
> Assuming that your vitrualenv is called `.venv`

**dependencies:**

- fzf
