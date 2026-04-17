import signal
from concurrent.futures import ThreadPoolExecutor

from termmodrinth.singleton import Singleton
from termmodrinth.cleaner import Cleaner
from termmodrinth.config import Config
from termmodrinth.logger import Logger
from termmodrinth.modrinth import project_types


def signal_handler(sig, frame):
    # Kein harter Prozesskill mehr – wir lösen einen normalen Abbruch aus,
    # den wir in Worker.run() sauber behandeln.
    Logger().log('wrn', "Interrupted (Ctrl+C). Shutting down gracefully…", "yellow")
    raise KeyboardInterrupt


class Worker(Singleton):
    def _new(self):
        self.tp_executor = ThreadPoolExecutor(max_workers=Config().threads())

    def updateProject(self, project_type, slug):
        if Cleaner().appenSlug(project_type, slug):
            try:
                # eigentlicher Aufruf deiner Projektklasse
                project_types[project_type]['class'](slug).update()

            except SystemExit as e:
                # kommt z. B. von argparse/click/sys.exit – nicht mehr durchreichen
                Logger().projectLog('wrn', project_type, slug,
                                    f"SystemExit intercepted: {e}", "yellow")

            except KeyboardInterrupt:
                # STRG+C respektieren → weiter nach oben
                raise

            except TypeError as e:
                # Klassischer Folgefehler nach vd == None → vd['...'] → NoneType not subscriptable
                msg = str(e)
                if "NoneType" in msg and "subscriptable" in msg:
                    Logger().projectLog(
                        'wrn',
                        project_type,
                        slug,
                        "Skipped: no compatible version (None was propagated) → ignoring.",
                        "yellow"
                    )
                else:
                    Logger().projectLog('err', project_type, slug,
                                        f"Update failure (TypeError): {e}", "red")

            except KeyError as e:
                # Wenn irgendwo auf fehlende Keys zugegriffen wird (z. B. vd['files'])
                Logger().projectLog('wrn', project_type, slug,
                                    f"Skipped: missing key {e!r} in version data.", "yellow")

            except Exception as e:
                # Restliche Fehler sauber loggen, aber nicht hart abbrechen
                Logger().projectLog('err', project_type, slug,
                                    f"Update failure: {e}", "red")
        else:
            Logger().projectLog('inf', project_type, slug,
                                "Already updated", "light_blue")

    def update(self):
        for project_type in project_types.keys():
            for slug in Config().projects(project_type):
                self.appendThread(project_type, slug)

    def appendThread(self, project_type, slug):
        self.tp_executor.submit(self.updateProject, project_type, slug)

    def run(self):
        # SIGINT sauber behandeln
        signal.signal(signal.SIGINT, signal_handler)
        try:
            self.update()
            # normal warten, Tasks fertiglaufen lassen
            self.tp_executor.shutdown(wait=True, cancel_futures=False)
        except KeyboardInterrupt:
            Logger().log('wrn', "Cancelling remaining tasks…", "yellow")
            # bei Abbruch: laufende Jobs nicht mehr abwarten, ausstehende canceln
            self.tp_executor.shutdown(wait=False, cancel_futures=True)
        finally:
            # immer aufräumen & Stats zeigen – auch wenn abgebrochen wurde
            Cleaner().cleanup()
            Cleaner().printStats()
