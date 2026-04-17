import json
import urllib.request
import urllib.parse
import time
import os
import hashlib
import pathlib

from termmodrinth.singleton import Singleton
from termmodrinth.config import Config
from termmodrinth.logger import Logger
from termmodrinth import version
from termmodrinth.utils import convert_isoformat_date


class ModrinthAPI(Singleton):
  def _new(self):
    # self.apiURL = "https://staging-api.modrinth.com/v2/"
    self.apiURL = "https://api.modrinth.com/v2/"
    self.cache = {}
    self.resetQPS()
    self.totlal_requests = 0
    self.init_time = time.time()
    self.request_headers = {
      'User-Agent': 'User-Agent: Sheridan/termmodrinth/{} (sheridan@babylon-five.ru)'.format(version)
    }
    self.tmp_path = "{}/queries".format(Config().tmpPath())
    os.makedirs(self.tmp_path, exist_ok=True)

  # ------------- Utilities -------------

  def dump_json(self, data):
    print(json.dumps(data, indent=2))

  def quote(self, string):
    # Modrinth akzeptiert JSON-Arrays in der Query; hier werden Einzelwerte mit %22 gequotet
    return "%22{}%22".format(string)

  def resetQPS(self):
    self.requests = 0
    self.time = time.time()

  def checkQPS(self):
    delta = time.time() - self.time
    if self.requests >= Config().qps() and delta < 1:
      sleepTime = delta * 2
      Logger().log("inf", "QPS sleep {}s".format(round(sleepTime, 2)), "blue")
      time.sleep(sleepTime)
      self.resetQPS()

  def createRequest(self, url):
    return urllib.request.Request(url, data=None, headers=self.request_headers)

  def cacheFilename(self, url):
    return "{}/{}.json".format(self.tmp_path, hashlib.md5(url.encode()).hexdigest())

  def storeQueryResult(self, url, data):
    store_data = {
      "termmodrinth": {"query_url": url},
      "modrinth": {"api_query": {"result": {"data": data}}}
    }
    with open(self.cacheFilename(url), 'w', encoding='utf-8') as f:
      json.dump(store_data, f, ensure_ascii=True, indent=2)

  def hasQueryResult(self, url):
    filename = self.cacheFilename(url)
    if os.path.isfile(filename):
      return (int(time.time() - pathlib.Path(filename).stat().st_mtime) < Config().cacheLiveSecunds())
    return False

  def loadQueryResult(self, url):
    with open(self.cacheFilename(url), 'r', encoding='utf-8') as f:
      return json.load(f)

  def removeQueryResult(self, url):
    try:
      os.remove(self.cacheFilename(url))
    except OSError:
      pass

  # ------------- Config helpers (ohne Config().data) -------------

  def _loader_for(self, project_type: str) -> str:
    # existiert bei dir
    return Config().modrinthLoader(project_type)

  def _target_versions_for(self, project_type: str):
    # existiert bei dir
    return Config().modrinthMCVersions(project_type)

  def _fallback_to_latest(self, project_type: str) -> bool:
    # wenn Getter noch nicht existiert → Defaults
    try:
      return bool(Config().fallback_to_latest(project_type))
    except Exception:
      defaults = {'mods': False, 'resourcepacks': True, 'shaders': True}
      return defaults.get(project_type, False)

  def _allow_prereleases(self, project_type: str) -> bool:
    # wenn Getter noch nicht existiert → alles False
    try:
      return bool(Config().allow_prereleases(project_type))
    except Exception:
      return False

  # ------------- API core -------------

  def callAPI(self, query):
    """
    Führt eine GET-Anfrage aus, cached Ergebnis, beachtet QPS.
    Bei Fehlern: loggt und wirft Exception (kein harter Exit).
    """
    url = self.apiURL + query
    if self.hasQueryResult(url):
      Logger().log("inf", "Query {} loaded from cache file {}".format(url, self.cacheFilename(url)), "blue")
      return self.loadQueryResult(url)["modrinth"]["api_query"]["result"]["data"]
    try:
      self.checkQPS()
      with urllib.request.urlopen(self.createRequest(url)) as response:
        self.requests += 1
        self.totlal_requests += 1
        jdata = json.load(response)
        self.storeQueryResult(url, jdata)
        return jdata
    except Exception as e:
      self.removeQueryResult(url)
      Logger().log('err', "Failure call api ({}): {}".format(url, e), "red")
      # Wichtig: nicht den ganzen Prozess töten – Worker fängt Exceptions pro Item
      raise

  def loadProject(self, project_id):
    if project_id not in self.cache.keys():
      self.cache[project_id] = self.callAPI("project/{}".format(project_id))
    return self.cache[project_id]

  def loadSlug(self, project_id):
    pdata = self.loadProject(project_id)
    return (pdata["slug"], pdata["project_type"])

  # --- Version-Auswahl-Strategie ---

  @staticmethod
  def _vt_rank(v):
    t = (v.get("version_type") or "").lower()
    if t == "release": return 3
    if t == "beta":    return 2
    if t == "alpha":   return 1
    return 0

  def _pick_best_version(self, versions: list, allow_prereleases: bool):
    """
    Bevorzuge release > beta > alpha; dann neueste(date_published).
    Wenn allow_prereleases=False, filtere auf release; wenn leer, fallback auf alles.
    """
    if not versions:
      return None
    pool = versions
    if not allow_prereleases:
      only_release = [v for v in versions if (v.get("version_type") or "").lower() == "release"]
      pool = only_release if only_release else versions
    pool.sort(key=lambda v: (self._vt_rank(v), v.get("date_published", "")), reverse=True)
    return pool[0]

  # Abwärtskompatibel: „letzte“ (nach Datum) – falls irgendwo noch genutzt
  def mineLastVersion(self, data):
    data_item = data[0]
    for data_index in data:
      if convert_isoformat_date(data_index["date_published"]) > convert_isoformat_date(data_item["date_published"]):
        data_item = data_index
    return data_item

  # Interne Helfer zum Bauen der Query
  def _versions_query(self, slug: str, loader: str, mc_version: str | None, featured: bool | None):
    base = f'project/{slug}/version?'
    parts = []
    if mc_version:
      parts.append('game_versions=[{}]'.format(self.quote(mc_version)))
    if loader:
      parts.append('loaders=[{}]'.format(self.quote(loader)))
    if featured is True:
      parts.append('featured=true')
    elif featured is False:
      parts.append('featured=false')
    return base + "&".join(parts)

  # ------------- Öffentliche Methode: loadProjectVersion -------------

  def loadProjectVersion(self, slug, project_type):
    """
    Versucht erst Ziel-MC-Version(en) + Loader (featured → unfeatured).
    Bei 0 Treffern und erlaubtem Fallback: suche nur mit Loader (ohne game_versions) und nimm beste Version.
    Resultat wird gecached unter key "<slug>:<project_type>".
    """
    key = "{}:{}".format(slug, project_type)
    if key in self.cache.keys():
      return self.cache[key]

    loader = self._loader_for(project_type)
    target_versions = self._target_versions_for(project_type) or []
    allow_pre = self._allow_prereleases(project_type)

    picked = None

    # 1) Zielversion(en) versuchen – zuerst featured, dann unfeatured
    for mc_version in target_versions:
      try:
        # featured first – schnellste „neueste stabile“ pro Kombi
        api_path = self._versions_query(slug, loader, mc_version, featured=True)
        pdata = self.callAPI(api_path)
        if not isinstance(pdata, list):
          pdata = []

        if not pdata:
          # unfeatured (volle Liste)
          api_path = self._versions_query(slug, loader, mc_version, featured=None)
          pdata = self.callAPI(api_path)
          if not isinstance(pdata, list):
            pdata = []

        if pdata:
          picked = self._pick_best_version(pdata, allow_prereleases=allow_pre)
          if picked:
            Logger().projectLog('inf', project_type, slug,
                                "Selected version for {}: {}".format(mc_version, picked.get("version_number")), "yellow")
            break
        else:
          Logger().projectLog('wrn', project_type, slug,
                              "Unavailable for Minecraft version {}".format(mc_version), "light_grey")
      except Exception as e:
        Logger().projectLog('err', project_type, slug,
                            "Modrinth query failed (target {}): {}".format(mc_version, e), "red")

    # 2) Fallback: neueste Version (erst mit Loader, dann ohne Loader), unabhängig von MC-Version
    if not picked and self._fallback_to_latest(project_type):
      try:
        fbdata = []

        # 2a) mit Loader + featured
        api_path = self._versions_query(slug, loader, None, featured=True)
        try:
          fbdata = self.callAPI(api_path)
          if not isinstance(fbdata, list):
            fbdata = []
        except Exception as e:
          Logger().projectLog('err', project_type, slug,
                              "Modrinth fallback query (loader+featured) failed: {}".format(e), "red")
          fbdata = []

        # 2b) mit Loader, ohne featured-Einschränkung
        if not fbdata:
          api_path = self._versions_query(slug, loader, None, featured=None)
          try:
            fbdata = self.callAPI(api_path)
            if not isinstance(fbdata, list):
              fbdata = []
          except Exception as e:
            Logger().projectLog('err', project_type, slug,
                                "Modrinth fallback query (loader any) failed: {}".format(e), "red")
            fbdata = []

        # 2c) letzter Versuch: komplett ohne Loader-Filter (manche Resourcepacks haben keinen Loader-Tag)
        if not fbdata:
          api_path = self._versions_query(slug, loader=None, mc_version=None, featured=True)
          try:
            fbdata = self.callAPI(api_path)
            if not isinstance(fbdata, list):
              fbdata = []
          except Exception as e:
            Logger().projectLog('err', project_type, slug,
                                "Modrinth fallback query (no loader + featured) failed: {}".format(e), "red")
            fbdata = []

        if not fbdata:
          api_path = self._versions_query(slug, loader=None, mc_version=None, featured=None)
          try:
            fbdata = self.callAPI(api_path)
            if not isinstance(fbdata, list):
              fbdata = []
          except Exception as e:
            Logger().projectLog('err', project_type, slug,
                                "Modrinth fallback query (no loader any) failed: {}".format(e), "red")
            fbdata = []

        if fbdata:
          picked = self._pick_best_version(fbdata, allow_prereleases=allow_pre)
          if picked:
            used_loader = loader if loader else "none"
            Logger().projectLog(
              'wrn', project_type, slug,
              "Using fallback latest (loader={}): {} (supports {})".format(
                used_loader,
                picked.get('version_number'),
                picked.get('game_versions')
              ),
              "yellow"
            )
      except Exception as e:
        Logger().projectLog('err', project_type, slug,
                            "Modrinth fallback query failed: {}".format(e), "red")

    # 3) Ergebnis cachen/returnen
    if not picked:
      Logger().projectLog('wrn', project_type, slug,
                          "No compatible version for this Minecraft version - skipping.", "yellow")
      self.cache[key] = None
      return None

    self.cache[key] = picked
    return picked

  # ------------- Stats -------------

  def stats(self):
    time_spent = time.time() - self.init_time
    return (self.totlal_requests, time.strftime("%H:%M:%S", time.gmtime(time_spent)), round(self.totlal_requests/time_spent, 2))
