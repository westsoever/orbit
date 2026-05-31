(.venv) lyo@MacBookAir orbit % python3 -m orbit.capture.daemon --db ./orbit.db
2026-05-22 23:26:21,105 INFO     __main__ — Database opened at ./orbit.db
2026-05-22 23:26:21,500 INFO     __main__ — Status bar initialized
2026-05-22 23:26:21,533 INFO     orbit.capture.worker — Capture worker started
2026-05-22 23:26:21,533 INFO     orbit.embed.worker — Embedding worker started
2026-05-22 23:26:21,533 INFO     __main__ — Orbit daemon running. Switch app focus to capture context. Ctrl-C to stop.
2026-05-22 23:27:03,854 INFO     orbit.capture.worker — Captured event 1 for com.superset.desktop (17 atoms)
2026-05-22 23:27:03,889 INFO     sentence_transformers.base.model — No device provided, using mps
2026-05-22 23:27:03,893 INFO     sentence_transformers.base.model — Loading SentenceTransformer model from sentence-transformers/all-MiniLM-L6-v2.
Loading weights: 100%|████████████████████████████████████████████████████████████████████████| 103/103 [00:00<00:00, 4941.47it/s]
2026-05-22 23:27:04,633 INFO     orbit.embed.worker — Embedding model loaded on device: mps:0
Batches:   0%|                                                                                              | 0/1 [00:00<?, ?it/s]Traceback (most recent call last):
  File "<frozen runpy>", line 198, in _run_module_as_main
  File "<frozen runpy>", line 88, in _run_code
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/main.py", line 83, in <module>
    main(app_bundle, output_accessibility_file, output_screenshot_file, max_depth)
    ~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/main.py", line 34, in main
    window_element = get_main_window(windows, max_depth)
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/main.py", line 17, in get_main_window
    main_window = max([(window, len(window.recursive_children())) for window in ui_windows], key=lambda x: x[1])[0]
                  ~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
ValueError: max() iterable argument is empty
Failed to extract app accessibility for com.apple.dock. Error: None
2026-05-22 23:27:08,292 ERROR    orbit.capture.worker — get_tree failed for com.apple.dock
Traceback (most recent call last):
  File "/Users/lyo/aiw/orbit/orbit/capture/worker.py", line 39, in run_capture_worker
    tree = get_tree(bundle, max_depth=max_depth)
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/run.py", line 35, in get_tree
    raise e
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/run.py", line 31, in get_tree
    subprocess.check_call(command)
    ~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^
  File "/Users/lyo/aiw/orbit/orbit/capture/axbridge.py", line 20, in <lambda>
    _subprocess.check_call = lambda cmd, **kw: _real_check_call(_patch_cmd(cmd), **{"stdout": _subprocess.DEVNULL, **kw})
                                               ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/homebrew/Cellar/python@3.13/3.13.12_1/Frameworks/Python.framework/Versions/3.13/lib/python3.13/subprocess.py", line 419, in check_call
    raise CalledProcessError(retcode, cmd)
subprocess.CalledProcessError: Command '['/Users/lyo/aiw/orbit/.venv/bin/python3', '-m', 'macapptree.main', '-a', 'com.apple.dock', '--oa', '/var/folders/w8/p56l577n0zj220q0tkrvsdxr0000gn/T/tmpq0ghxlc3', '--max-depth', '12']' returned non-zero exit status 1.
Batches: 100%|██████████████████████████████████████████████████████████████████████████████████████| 1/1 [00:04<00:00,  4.38s/it]
2026-05-22 23:27:10,376 INFO     orbit.capture.worker — Captured event 2 for com.superset.desktop (17 atoms)
Batches: 100%|██████████████████████████████████████████████████████████████████████████████████████| 1/1 [00:00<00:00,  3.43it/s]
Traceback (most recent call last):
  File "<frozen runpy>", line 198, in _run_module_as_main
  File "<frozen runpy>", line 88, in _run_code
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/main.py", line 83, in <module>
    main(app_bundle, output_accessibility_file, output_screenshot_file, max_depth)
    ~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/main.py", line 34, in main
    window_element = get_main_window(windows, max_depth)
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/main.py", line 17, in get_main_window
    main_window = max([(window, len(window.recursive_children())) for window in ui_windows], key=lambda x: x[1])[0]
                  ~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
ValueError: max() iterable argument is empty
Failed to extract app accessibility for com.apple.dock. Error: None
2026-05-22 23:27:13,899 ERROR    orbit.capture.worker — get_tree failed for com.apple.dock
Traceback (most recent call last):
  File "/Users/lyo/aiw/orbit/orbit/capture/worker.py", line 39, in run_capture_worker
    tree = get_tree(bundle, max_depth=max_depth)
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/run.py", line 35, in get_tree
    raise e
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/run.py", line 31, in get_tree
    subprocess.check_call(command)
    ~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^
  File "/Users/lyo/aiw/orbit/orbit/capture/axbridge.py", line 20, in <lambda>
    _subprocess.check_call = lambda cmd, **kw: _real_check_call(_patch_cmd(cmd), **{"stdout": _subprocess.DEVNULL, **kw})
                                               ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/homebrew/Cellar/python@3.13/3.13.12_1/Frameworks/Python.framework/Versions/3.13/lib/python3.13/subprocess.py", line 419, in check_call
    raise CalledProcessError(retcode, cmd)
subprocess.CalledProcessError: Command '['/Users/lyo/aiw/orbit/.venv/bin/python3', '-m', 'macapptree.main', '-a', 'com.apple.dock', '--oa', '/var/folders/w8/p56l577n0zj220q0tkrvsdxr0000gn/T/tmpufvw1uj2', '--max-depth', '12']' returned non-zero exit status 1.
2026-05-22 23:27:15,562 INFO     orbit.capture.worker — Captured event 3 for com.superset.desktop (17 atoms)
Batches: 100%|██████████████████████████████████████████████████████████████████████████████████████| 1/1 [00:00<00:00,  3.36it/s]
Traceback (most recent call last):
  File "<frozen runpy>", line 198, in _run_module_as_main
  File "<frozen runpy>", line 88, in _run_code
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/main.py", line 83, in <module>
    main(app_bundle, output_accessibility_file, output_screenshot_file, max_depth)
    ~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/main.py", line 34, in main
    window_element = get_main_window(windows, max_depth)
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/main.py", line 17, in get_main_window
    main_window = max([(window, len(window.recursive_children())) for window in ui_windows], key=lambda x: x[1])[0]
                  ~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
ValueError: max() iterable argument is empty
Failed to extract app accessibility for com.apple.dock. Error: None
2026-05-22 23:27:17,311 ERROR    orbit.capture.worker — get_tree failed for com.apple.dock
Traceback (most recent call last):
  File "/Users/lyo/aiw/orbit/orbit/capture/worker.py", line 39, in run_capture_worker
    tree = get_tree(bundle, max_depth=max_depth)
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/run.py", line 35, in get_tree
    raise e
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/run.py", line 31, in get_tree
    subprocess.check_call(command)
    ~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^
  File "/Users/lyo/aiw/orbit/orbit/capture/axbridge.py", line 20, in <lambda>
    _subprocess.check_call = lambda cmd, **kw: _real_check_call(_patch_cmd(cmd), **{"stdout": _subprocess.DEVNULL, **kw})
                                               ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/homebrew/Cellar/python@3.13/3.13.12_1/Frameworks/Python.framework/Versions/3.13/lib/python3.13/subprocess.py", line 419, in check_call
    raise CalledProcessError(retcode, cmd)
subprocess.CalledProcessError: Command '['/Users/lyo/aiw/orbit/.venv/bin/python3', '-m', 'macapptree.main', '-a', 'com.apple.dock', '--oa', '/var/folders/w8/p56l577n0zj220q0tkrvsdxr0000gn/T/tmpg70rao12', '--max-depth', '12']' returned non-zero exit status 1.
Traceback (most recent call last):
  File "<frozen runpy>", line 198, in _run_module_as_main
  File "<frozen runpy>", line 88, in _run_code
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/main.py", line 83, in <module>
    main(app_bundle, output_accessibility_file, output_screenshot_file, max_depth)
    ~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/main.py", line 34, in main
    window_element = get_main_window(windows, max_depth)
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/main.py", line 17, in get_main_window
    main_window = max([(window, len(window.recursive_children())) for window in ui_windows], key=lambda x: x[1])[0]
                  ~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
ValueError: max() iterable argument is empty
Failed to extract app accessibility for com.superset.desktop. Error: None
2026-05-22 23:27:19,037 ERROR    orbit.capture.worker — get_tree failed for com.superset.desktop
Traceback (most recent call last):
  File "/Users/lyo/aiw/orbit/orbit/capture/worker.py", line 39, in run_capture_worker
    tree = get_tree(bundle, max_depth=max_depth)
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/run.py", line 35, in get_tree
    raise e
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/run.py", line 31, in get_tree
    subprocess.check_call(command)
    ~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^
  File "/Users/lyo/aiw/orbit/orbit/capture/axbridge.py", line 20, in <lambda>
    _subprocess.check_call = lambda cmd, **kw: _real_check_call(_patch_cmd(cmd), **{"stdout": _subprocess.DEVNULL, **kw})
                                               ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/homebrew/Cellar/python@3.13/3.13.12_1/Frameworks/Python.framework/Versions/3.13/lib/python3.13/subprocess.py", line 419, in check_call
    raise CalledProcessError(retcode, cmd)
subprocess.CalledProcessError: Command '['/Users/lyo/aiw/orbit/.venv/bin/python3', '-m', 'macapptree.main', '-a', 'com.superset.desktop', '--oa', '/var/folders/w8/p56l577n0zj220q0tkrvsdxr0000gn/T/tmpi5p7gn3g', '--max-depth', '12']' returned non-zero exit status 1.
Traceback (most recent call last):
  File "<frozen runpy>", line 198, in _run_module_as_main
  File "<frozen runpy>", line 88, in _run_code
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/main.py", line 83, in <module>
    main(app_bundle, output_accessibility_file, output_screenshot_file, max_depth)
    ~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/main.py", line 34, in main
    window_element = get_main_window(windows, max_depth)
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/main.py", line 17, in get_main_window
    main_window = max([(window, len(window.recursive_children())) for window in ui_windows], key=lambda x: x[1])[0]
                  ~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
ValueError: max() iterable argument is empty
Failed to extract app accessibility for com.apple.dock. Error: None
2026-05-22 23:27:22,444 ERROR    orbit.capture.worker — get_tree failed for com.apple.dock
Traceback (most recent call last):
  File "/Users/lyo/aiw/orbit/orbit/capture/worker.py", line 39, in run_capture_worker
    tree = get_tree(bundle, max_depth=max_depth)
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/run.py", line 35, in get_tree
    raise e
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/run.py", line 31, in get_tree
    subprocess.check_call(command)
    ~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^
  File "/Users/lyo/aiw/orbit/orbit/capture/axbridge.py", line 20, in <lambda>
    _subprocess.check_call = lambda cmd, **kw: _real_check_call(_patch_cmd(cmd), **{"stdout": _subprocess.DEVNULL, **kw})
                                               ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/homebrew/Cellar/python@3.13/3.13.12_1/Frameworks/Python.framework/Versions/3.13/lib/python3.13/subprocess.py", line 419, in check_call
    raise CalledProcessError(retcode, cmd)
subprocess.CalledProcessError: Command '['/Users/lyo/aiw/orbit/.venv/bin/python3', '-m', 'macapptree.main', '-a', 'com.apple.dock', '--oa', '/var/folders/w8/p56l577n0zj220q0tkrvsdxr0000gn/T/tmpfd2oy0wg', '--max-depth', '12']' returned non-zero exit status 1.
2026-05-22 23:27:24,120 INFO     orbit.capture.worker — Captured event 4 for com.superset.desktop (17 atoms)
Batches: 100%|██████████████████████████████████████████████████████████████████████████████████████| 1/1 [00:00<00:00,  3.17it/s]
Traceback (most recent call last):
  File "<frozen runpy>", line 198, in _run_module_as_main
  File "<frozen runpy>", line 88, in _run_code
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/main.py", line 83, in <module>
    main(app_bundle, output_accessibility_file, output_screenshot_file, max_depth)
    ~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/main.py", line 34, in main
    window_element = get_main_window(windows, max_depth)
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/main.py", line 17, in get_main_window
    main_window = max([(window, len(window.recursive_children())) for window in ui_windows], key=lambda x: x[1])[0]
                  ~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
ValueError: max() iterable argument is empty
Failed to extract app accessibility for org.python.python. Error: None
2026-05-22 23:27:25,899 ERROR    orbit.capture.worker — get_tree failed for org.python.python
Traceback (most recent call last):
  File "/Users/lyo/aiw/orbit/orbit/capture/worker.py", line 39, in run_capture_worker
    tree = get_tree(bundle, max_depth=max_depth)
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/run.py", line 35, in get_tree
    raise e
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/run.py", line 31, in get_tree
    subprocess.check_call(command)
    ~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^
  File "/Users/lyo/aiw/orbit/orbit/capture/axbridge.py", line 20, in <lambda>
    _subprocess.check_call = lambda cmd, **kw: _real_check_call(_patch_cmd(cmd), **{"stdout": _subprocess.DEVNULL, **kw})
                                               ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/homebrew/Cellar/python@3.13/3.13.12_1/Frameworks/Python.framework/Versions/3.13/lib/python3.13/subprocess.py", line 419, in check_call
    raise CalledProcessError(retcode, cmd)
subprocess.CalledProcessError: Command '['/Users/lyo/aiw/orbit/.venv/bin/python3', '-m', 'macapptree.main', '-a', 'org.python.python', '--oa', '/var/folders/w8/p56l577n0zj220q0tkrvsdxr0000gn/T/tmpd2f1562q', '--max-depth', '12']' returned non-zero exit status 1.
Traceback (most recent call last):
  File "<frozen runpy>", line 198, in _run_module_as_main
  File "<frozen runpy>", line 88, in _run_code
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/main.py", line 83, in <module>
    main(app_bundle, output_accessibility_file, output_screenshot_file, max_depth)
    ~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/main.py", line 34, in main
    window_element = get_main_window(windows, max_depth)
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/main.py", line 17, in get_main_window
    main_window = max([(window, len(window.recursive_children())) for window in ui_windows], key=lambda x: x[1])[0]
                  ~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
ValueError: max() iterable argument is empty
Failed to extract app accessibility for com.apple.dock. Error: None
2026-05-22 23:27:27,533 ERROR    orbit.capture.worker — get_tree failed for com.apple.dock
Traceback (most recent call last):
  File "/Users/lyo/aiw/orbit/orbit/capture/worker.py", line 39, in run_capture_worker
    tree = get_tree(bundle, max_depth=max_depth)
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/run.py", line 35, in get_tree
    raise e
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/run.py", line 31, in get_tree
    subprocess.check_call(command)
    ~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^
  File "/Users/lyo/aiw/orbit/orbit/capture/axbridge.py", line 20, in <lambda>
    _subprocess.check_call = lambda cmd, **kw: _real_check_call(_patch_cmd(cmd), **{"stdout": _subprocess.DEVNULL, **kw})
                                               ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/homebrew/Cellar/python@3.13/3.13.12_1/Frameworks/Python.framework/Versions/3.13/lib/python3.13/subprocess.py", line 419, in check_call
    raise CalledProcessError(retcode, cmd)
subprocess.CalledProcessError: Command '['/Users/lyo/aiw/orbit/.venv/bin/python3', '-m', 'macapptree.main', '-a', 'com.apple.dock', '--oa', '/var/folders/w8/p56l577n0zj220q0tkrvsdxr0000gn/T/tmp21wbocf3', '--max-depth', '12']' returned non-zero exit status 1.
2026-05-22 23:27:29,201 INFO     orbit.capture.worker — Captured event 5 for com.superset.desktop (17 atoms)
Batches: 100%|██████████████████████████████████████████████████████████████████████████████████████| 1/1 [00:00<00:00,  3.29it/s]
2026-05-22 23:27:31,111 INFO     orbit.capture.worker — Captured event 6 for com.google.Chrome (5 atoms)
Batches: 100%|██████████████████████████████████████████████████████████████████████████████████████| 1/1 [00:01<00:00,  1.37s/it]
2026-05-22 23:27:32,899 INFO     orbit.capture.worker — Captured event 7 for com.superset.desktop (17 atoms)
Batches: 100%|██████████████████████████████████████████████████████████████████████████████████████| 1/1 [00:00<00:00, 42.42it/s]
Traceback (most recent call last):
  File "<frozen runpy>", line 198, in _run_module_as_main
  File "<frozen runpy>", line 88, in _run_code
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/main.py", line 83, in <module>
    main(app_bundle, output_accessibility_file, output_screenshot_file, max_depth)
    ~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/main.py", line 34, in main
    window_element = get_main_window(windows, max_depth)
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/main.py", line 17, in get_main_window
    main_window = max([(window, len(window.recursive_children())) for window in ui_windows], key=lambda x: x[1])[0]
                  ~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
ValueError: max() iterable argument is empty
Failed to extract app accessibility for com.apple.dock. Error: None
2026-05-22 23:27:36,322 ERROR    orbit.capture.worker — get_tree failed for com.apple.dock
Traceback (most recent call last):
  File "/Users/lyo/aiw/orbit/orbit/capture/worker.py", line 39, in run_capture_worker
    tree = get_tree(bundle, max_depth=max_depth)
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/run.py", line 35, in get_tree
    raise e
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/run.py", line 31, in get_tree
    subprocess.check_call(command)
    ~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^
  File "/Users/lyo/aiw/orbit/orbit/capture/axbridge.py", line 20, in <lambda>
    _subprocess.check_call = lambda cmd, **kw: _real_check_call(_patch_cmd(cmd), **{"stdout": _subprocess.DEVNULL, **kw})
                                               ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/homebrew/Cellar/python@3.13/3.13.12_1/Frameworks/Python.framework/Versions/3.13/lib/python3.13/subprocess.py", line 419, in check_call
    raise CalledProcessError(retcode, cmd)
subprocess.CalledProcessError: Command '['/Users/lyo/aiw/orbit/.venv/bin/python3', '-m', 'macapptree.main', '-a', 'com.apple.dock', '--oa', '/var/folders/w8/p56l577n0zj220q0tkrvsdxr0000gn/T/tmpowcfkkcq', '--max-depth', '12']' returned non-zero exit status 1.
2026-05-22 23:27:37,970 INFO     orbit.capture.worker — Captured event 8 for com.superset.desktop (17 atoms)
Batches: 100%|██████████████████████████████████████████████████████████████████████████████████████| 1/1 [00:00<00:00,  3.44it/s]
Traceback (most recent call last):
  File "<frozen runpy>", line 198, in _run_module_as_main
  File "<frozen runpy>", line 88, in _run_code
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/main.py", line 83, in <module>
    main(app_bundle, output_accessibility_file, output_screenshot_file, max_depth)
    ~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/main.py", line 34, in main
    window_element = get_main_window(windows, max_depth)
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/main.py", line 17, in get_main_window
    main_window = max([(window, len(window.recursive_children())) for window in ui_windows], key=lambda x: x[1])[0]
                  ~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
ValueError: max() iterable argument is empty
Failed to extract app accessibility for org.python.python. Error: None
2026-05-22 23:27:39,707 ERROR    orbit.capture.worker — get_tree failed for org.python.python
Traceback (most recent call last):
  File "/Users/lyo/aiw/orbit/orbit/capture/worker.py", line 39, in run_capture_worker
    tree = get_tree(bundle, max_depth=max_depth)
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/run.py", line 35, in get_tree
    raise e
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/run.py", line 31, in get_tree
    subprocess.check_call(command)
    ~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^
  File "/Users/lyo/aiw/orbit/orbit/capture/axbridge.py", line 20, in <lambda>
    _subprocess.check_call = lambda cmd, **kw: _real_check_call(_patch_cmd(cmd), **{"stdout": _subprocess.DEVNULL, **kw})
                                               ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/homebrew/Cellar/python@3.13/3.13.12_1/Frameworks/Python.framework/Versions/3.13/lib/python3.13/subprocess.py", line 419, in check_call
    raise CalledProcessError(retcode, cmd)
subprocess.CalledProcessError: Command '['/Users/lyo/aiw/orbit/.venv/bin/python3', '-m', 'macapptree.main', '-a', 'org.python.python', '--oa', '/var/folders/w8/p56l577n0zj220q0tkrvsdxr0000gn/T/tmpdmd350ct', '--max-depth', '12']' returned non-zero exit status 1.
Traceback (most recent call last):
  File "<frozen runpy>", line 198, in _run_module_as_main
  File "<frozen runpy>", line 88, in _run_code
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/main.py", line 83, in <module>
    main(app_bundle, output_accessibility_file, output_screenshot_file, max_depth)
    ~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/main.py", line 34, in main
    window_element = get_main_window(windows, max_depth)
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/main.py", line 17, in get_main_window
    main_window = max([(window, len(window.recursive_children())) for window in ui_windows], key=lambda x: x[1])[0]
                  ~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
ValueError: max() iterable argument is empty
Failed to extract app accessibility for com.apple.dock. Error: None
2026-05-22 23:27:41,292 ERROR    orbit.capture.worker — get_tree failed for com.apple.dock
Traceback (most recent call last):
  File "/Users/lyo/aiw/orbit/orbit/capture/worker.py", line 39, in run_capture_worker
    tree = get_tree(bundle, max_depth=max_depth)
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/run.py", line 35, in get_tree
    raise e
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/run.py", line 31, in get_tree
    subprocess.check_call(command)
    ~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^
  File "/Users/lyo/aiw/orbit/orbit/capture/axbridge.py", line 20, in <lambda>
    _subprocess.check_call = lambda cmd, **kw: _real_check_call(_patch_cmd(cmd), **{"stdout": _subprocess.DEVNULL, **kw})
                                               ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/homebrew/Cellar/python@3.13/3.13.12_1/Frameworks/Python.framework/Versions/3.13/lib/python3.13/subprocess.py", line 419, in check_call
    raise CalledProcessError(retcode, cmd)
subprocess.CalledProcessError: Command '['/Users/lyo/aiw/orbit/.venv/bin/python3', '-m', 'macapptree.main', '-a', 'com.apple.dock', '--oa', '/var/folders/w8/p56l577n0zj220q0tkrvsdxr0000gn/T/tmprgxd3niw', '--max-depth', '12']' returned non-zero exit status 1.
2026-05-22 23:27:43,034 INFO     orbit.capture.worker — Captured event 9 for com.superset.desktop (17 atoms)
Batches: 100%|██████████████████████████████████████████████████████████████████████████████████████| 1/1 [00:00<00:00,  2.42it/s]
2026-05-22 23:27:45,167 INFO     orbit.capture.worker — Captured event 10 for com.google.Chrome (5 atoms)
Batches: 100%|██████████████████████████████████████████████████████████████████████████████████████| 1/1 [00:00<00:00,  3.88it/s]
^CTraceback (most recent call last):
  File "<frozen runpy>", line 198, in _run_module_as_main
  File "<frozen runpy>", line 88, in _run_code
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/main.py", line 83, in <module>
    main(app_bundle, output_accessibility_file, output_screenshot_file, max_depth)
    ~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/main.py", line 29, in main
    time.sleep(1)
    ~~~~~~~~~~^^^
KeyboardInterrupt
Failed to extract app accessibility for com.superset.desktop. Error: None
2026-05-22 23:27:46,635 ERROR    orbit.capture.worker — get_tree failed for com.superset.desktop
Traceback (most recent call last):
  File "/Users/lyo/aiw/orbit/orbit/capture/worker.py", line 39, in run_capture_worker
    tree = get_tree(bundle, max_depth=max_depth)
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/run.py", line 35, in get_tree
    raise e
  File "/Users/lyo/aiw/orbit/.venv/lib/python3.13/site-packages/macapptree/run.py", line 31, in get_tree
    subprocess.check_call(command)
    ~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^
  File "/Users/lyo/aiw/orbit/orbit/capture/axbridge.py", line 20, in <lambda>
    _subprocess.check_call = lambda cmd, **kw: _real_check_call(_patch_cmd(cmd), **{"stdout": _subprocess.DEVNULL, **kw})
                                               ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/homebrew/Cellar/python@3.13/3.13.12_1/Frameworks/Python.framework/Versions/3.13/lib/python3.13/subprocess.py", line 419, in check_call
    raise CalledProcessError(retcode, cmd)
subprocess.CalledProcessError: Command '['/Users/lyo/aiw/orbit/.venv/bin/python3', '-m', 'macapptree.main', '-a', 'com.superset.desktop', '--oa', '/var/folders/w8/p56l577n0zj220q0tkrvsdxr0000gn/T/tmpp_76m_6u', '--max-depth', '12']' died with <Signals.SIGINT: 2>.
*** Terminating app due to uncaught exception 'OC_PythonException', reason: '<class 'KeyboardInterrupt'>: '
*** First throw call stack:
(
        0   CoreFoundation                      0x00000001828a58ec __exceptionPreprocess + 176
        1   libobjc.A.dylib                     0x000000018237e418 objc_exception_throw + 88
        2   _objc.cpython-313-darwin.so         0x0000000107db0150 python_exception_to_objc + 0
        3   _objc.cpython-313-darwin.so         0x0000000107d6cb28 method_stub + 13736
        4   libffi.dylib                        0x0000000196abda34 ffi_closure_SYSV_inner + 852
        5   libffi.dylib                        0x0000000196ab41e8 ffi_closure_SYSV + 56
        6   CoreFoundation                      0x000000018284f494 __CFNOTIFICATIONCENTER_IS_CALLING_OUT_TO_AN_OBSERVER__ + 148
        7   CoreFoundation                      0x00000001828b3f44 ___CFXRegistrationPost_block_invoke + 92
        8   CoreFoundation                      0x00000001828b3e88 _CFXRegistrationPost + 436
        9   CoreFoundation                      0x000000018282df94 _CFXNotificationPost + 740
        10  Foundation                          0x0000000184a573a0 -[NSNotificationCenter postNotificationName:object:userInfo:] + 88
        11  AppKit                              0x0000000186d2e634 applicationStatusSubsystemCallback + 728
        12  LaunchServices                      0x0000000182d62028 ___LSScheduleNotificationFunction_block_invoke_2 + 52
        13  CoreFoundation                      0x0000000182858604 __CFRUNLOOP_IS_CALLING_OUT_TO_A_BLOCK__ + 28
        14  CoreFoundation                      0x0000000182858544 __CFRunLoopDoBlocks + 396
        15  CoreFoundation                      0x0000000182857988 __CFRunLoopRun + 2356
        16  CoreFoundation                      0x0000000182911e34 _CFRunLoopRunSpecificWithOptions + 532
        17  Foundation                          0x0000000184aa6964 -[NSRunLoop(NSRunLoop) runMode:beforeDate:] + 212
        18  Foundation                          0x0000000184aa6b68 -[NSRunLoop(NSRunLoop) runUntilDate:] + 100
        19  libffi.dylib                        0x0000000196ab4050 ffi_call_SYSV + 80
        20  libffi.dylib                        0x0000000196abd604 ffi_call_int + 1220
        21  _objc.cpython-313-darwin.so         0x0000000107d782f8 PyObjCFFI_Caller_SimpleSEL + 1360
        22  _objc.cpython-313-darwin.so         0x0000000107dc2290 objcsel_vectorcall_simple + 1280
        23  Python                              0x0000000102e3fde4 PyObject_Vectorcall + 92
        24  Python                              0x0000000102f662ec _PyEval_EvalFrameDefault + 6752
        25  Python                              0x0000000102f64610 PyEval_EvalCode + 200
        26  Python                              0x0000000102f5f8e4 builtin_exec + 440
        27  Python                              0x0000000102e9bca4 cfunction_vectorcall_FASTCALL_KEYWORDS + 88
        28  Python                              0x0000000102e3fde4 PyObject_Vectorcall + 92
        29  Python                              0x0000000102f65c88 _PyEval_EvalFrameDefault + 5116
        30  Python                              0x0000000102ff8af0 pymain_run_module + 228
        31  Python                              0x0000000102ff7ed4 Py_RunMain + 204
        32  Python                              0x0000000102ff87cc pymain_main + 304
        33  Python                              0x0000000102ff886c Py_BytesMain + 40
        34  dyld                                0x00000001823f1d54 start + 7184
)
libc++abi: terminating due to uncaught exception of type NSException
zsh: abort      python3 -m orbit.capture.daemon --db ./orbit.db
(.venv) lyo@MacBookAir orbit % /opt/homebrew/Cellar/python@3.13/3.13.12_1/Frameworks/Python.framework/Versions/3.13/lib/python3.13/multiprocessing/resource_tracker.py:400: UserWarning: resource_tracker: There appear to be 1 leaked semaphore objects to clean up at shutdown: {'/loky-13090-dekk787v'}
  warnings.warn(