import json
import os

from termmodrinth.singleton import Singleton

class Config(Singleton):
  def _new(self):
    base_dir = os.path.dirname(os.path.abspath(__file__))
    config_file = os.path.normpath(os.path.join(base_dir, "..", "..", "..", "config", "modpack-extender.json"))

    with open(config_file, 'r', encoding='utf-8') as f:
      self.conf_data = json.load(f)

    self._module_root = os.path.normpath(os.path.join(base_dir, "..",))

    self._qps = int(self.conf_data["modrinth"]["max_queries_per_minute"] / 60)
    self._paths = {}

  # ---------- intern ----------

  def _resolve(self, p: str) -> str:
    if os.path.isabs(p):
      return p
    return os.path.normpath(os.path.join(self._module_root, p))

  def _triState(self, key, project_type_plural, default=False):
    """
    Liest bools entweder global (True/False) oder je Typ aus einem Dict.
    """
    v = self.conf_data.get("modrinth", {}).get(key, default)
    if isinstance(v, bool):
      return v
    if isinstance(v, dict):
      # akzeptiere sowohl "mods"/"resourcepacks"/"shaders" als auch Singular-Keys
      if project_type_plural in v:
        return bool(v[project_type_plural])
      # fallback auf "global"
      if "global" in v:
        return bool(v["global"])
    return default

  # ---------- Basics ----------

  def threads(self): return self.conf_data["threads"]
  def qps(self): return self._qps

  def filterListComment(self, data): return list(filter(lambda x: not str(x).startswith("#"), data))

  def projects(self, project_type):  # project_type: "mod" | "resourcepack" | "shader"
    return self.filterListComment(self.conf_data[project_type+'s'])

  # ---------- Modrinth: Ziel, Loader, Flags ----------

  def modrinthLoader(self, project_type):  # returns str
    return self.conf_data["modrinth"]["loader"][project_type+'s']

  def modrinthMCVersions(self, project_type):  # returns list[str]
    return self.filterListComment(self.conf_data["modrinth"]["minecraft_versions"][project_type+'s'])

  # Convenience-Getter (werden von neuer api.py NICHT zwingend benötigt, aber sauber implementiert)
  def loader_for(self, project_type: str) -> str:
    # delegiert korrekt auf conf_data
    return self.modrinthLoader(project_type)

  def target_mc_version_for(self, project_type: str):
    lst = self.modrinthMCVersions(project_type)
    return lst[0] if lst else None

  def fallback_to_latest(self, project_type: str) -> bool:
    # liest "modrinth.fallback_to_latest"
    return self._triState("fallback_to_latest", project_type+'s', default=False)

  def allow_prereleases(self, project_type: str) -> bool:
    # liest "modrinth.allow_prereleases"
    return self._triState("allow_prereleases", project_type+'s', default=False)

  # ---------- Auth & Pfade ----------

  def modrinthLogin(self): return self.conf_data["modrinth"]["user"]["login"]
  def modrinthPassword(self): return self.conf_data["modrinth"]["user"]["password"]

  def cacheLiveSecunds(self): return self.conf_data["cache_lifetime_minutes"]*60
  def tmpPath(self): return self._resolve(self.conf_data["tmp_path"])

  def storage_path(self, project_type): return self.storage(project_type, "storage")

  def active_path(self, project_type):
    inst_root = self.conf_data.get("instance_path")
    if isinstance(inst_root, str) and inst_root.strip():
      subdir = "shaderpacks" if project_type == "shader" else f"{project_type}s"
      key = f"{project_type}:active_instance"
      if key not in self._paths:
        target = os.path.join(inst_root, subdir)
        os.makedirs(target, exist_ok=True)
        self._paths[key] = target
      return self._paths[key]
    return self.storage(project_type, "active")

  def storage(self, project_type, storage_type):
    storage_root = self._resolve(self.conf_data["storage"])
    key = f"{project_type}:{storage_type}"
    if key not in self._paths:
      path = os.path.join(storage_root, f"{project_type}s", storage_type)
      os.makedirs(path, exist_ok=True)
      self._paths[key] = path
    return self._paths[key]

  def primariesOnly(self, project_type): return self.conf_data["modrinth"]["primaries_only"][project_type+'s']
  def tryNotDownloadSources(self, project_type): return self.conf_data["modrinth"]["try_not_download_sources"][project_type+'s']

  def requestDependencies(self): return self.filterListComment(self.conf_data["modrinth"]["request_dependencies"])