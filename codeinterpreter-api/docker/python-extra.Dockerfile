# Extra Python packages layered on top of the base code-interpreter/python image.
FROM code-interpreter/python:latest

USER root

ARG PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
ARG PIP_TRUSTED_HOST=pypi.tuna.tsinghua.edu.cn

ENV PIP_INDEX_URL=${PIP_INDEX_URL} \
    PIP_TRUSTED_HOST=${PIP_TRUSTED_HOST} \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    fontconfig \
    fonts-noto-cjk \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /home/codeuser/.config/matplotlib \
    && chown -R codeuser:codeuser /home/codeuser

RUN printf '%s\n' \
    '<?xml version="1.0"?>' \
    '<!DOCTYPE fontconfig SYSTEM "fonts.dtd">' \
    '<fontconfig>' \
    '  <alias>' \
    '    <family>SimHei</family>' \
    '    <prefer>' \
    '      <family>Noto Sans CJK SC</family>' \
    '      <family>Noto Sans CJK JP</family>' \
    '      <family>Noto Sans CJK KR</family>' \
    '    </prefer>' \
    '  </alias>' \
    '</fontconfig>' \
    > /etc/fonts/conf.d/65-simhei.conf

RUN printf '%s\n' \
    'font.family: sans-serif' \
    'font.sans-serif: Noto Sans CJK JP, Noto Sans CJK SC, Noto Sans CJK KR, DejaVu Sans' \
    'axes.unicode_minus: False' \
    > /home/codeuser/.config/matplotlib/matplotlibrc

RUN printf '%s\n' \
    'import sys' \
    'from importlib.machinery import PathFinder' \
    '' \
    '_ALIAS_FAMILY = "SimHei"' \
    '_CANDIDATES = (' \
    '    "Noto Sans CJK SC",' \
    '    "Noto Sans CJK TC",' \
    '    "Noto Sans CJK JP",' \
    '    "Noto Sans CJK KR",' \
    '    "Noto Serif CJK SC",' \
    '    "Noto Serif CJK TC",' \
    '    "Noto Serif CJK JP",' \
    '    "Noto Serif CJK KR",' \
    '    "WenQuanYi Zen Hei",' \
    '    "WenQuanYi Micro Hei",' \
    ')' \
    '' \
    'def _patch_matplotlib():' \
    '    try:' \
    '        import matplotlib.font_manager as fm' \
    '    except Exception:' \
    '        return' \
    '    if any(f.name == _ALIAS_FAMILY for f in fm.fontManager.ttflist):' \
    '        return' \
    '    available = {f.name: f.fname for f in fm.fontManager.ttflist}' \
    '    target_path = None' \
    '    for name in _CANDIDATES:' \
    '        target_path = available.get(name)' \
    '        if target_path:' \
    '            break' \
    '    if not target_path:' \
    '        for f in fm.fontManager.ttflist:' \
    '            if "Noto Sans CJK" in f.name:' \
    '                target_path = f.fname' \
    '                break' \
    '    if not target_path:' \
    '        return' \
    '    fm.fontManager.ttflist.append(' \
    '        fm.FontEntry(' \
    '            fname=target_path,' \
    '            name=_ALIAS_FAMILY,' \
    '            style="normal",' \
    '            variant="normal",' \
    '            weight="normal",' \
    '            stretch="normal",' \
    '            size="scalable",' \
    '        )' \
    '    )' \
    '' \
    'class _MatplotlibPatchLoader:' \
    '    def __init__(self, loader, finder):' \
    '        self._loader = loader' \
    '        self._finder = finder' \
    '' \
    '    def create_module(self, spec):' \
    '        if hasattr(self._loader, "create_module"):' \
    '            return self._loader.create_module(spec)' \
    '        return None' \
    '' \
    '    def exec_module(self, module):' \
    '        self._loader.exec_module(module)' \
    '        _patch_matplotlib()' \
    '        self._finder._patched = True' \
    '        try:' \
    '            sys.meta_path.remove(self._finder)' \
    '        except ValueError:' \
    '            pass' \
    '' \
    'class _MatplotlibPatchFinder:' \
    '    def __init__(self):' \
    '        self._patched = False' \
    '' \
    '    def find_spec(self, fullname, path, target=None):' \
    '        if self._patched or fullname != "matplotlib":' \
    '            return None' \
    '        spec = PathFinder.find_spec(fullname, path)' \
    '        if spec is None or spec.loader is None:' \
    '            return None' \
    '        spec.loader = _MatplotlibPatchLoader(spec.loader, self)' \
    '        return spec' \
    '' \
    'if "matplotlib" in sys.modules:' \
    '    _patch_matplotlib()' \
    'else:' \
    '    sys.meta_path.insert(0, _MatplotlibPatchFinder())' \
    > /usr/local/lib/python3.13/site-packages/sitecustomize.py

RUN chown codeuser:codeuser /home/codeuser/.config/matplotlib/matplotlibrc \
    && fc-cache -f

COPY docker/requirements/python-extra.txt /tmp/python-extra.txt

RUN python -m pip install -r /tmp/python-extra.txt && rm -f /tmp/python-extra.txt

ENV HOME=/home/codeuser \
    MPLCONFIGDIR=/home/codeuser/.config/matplotlib

USER codeuser
