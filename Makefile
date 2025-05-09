VENV_NAME?=venv
VENV_ACTIVATE=. $(VENV_NAME)/bin/activate
PYTHON=${VENV_NAME}/bin/python3.12
DOCKER_IMAGE="ethereum/staking-deposit-cli:latest"

help:
	@echo "clean - remove build and Python file artifacts"
	# Run with venv
	@echo "venv_deposit - run deposit cli with venv"
	@echo "venv_build - install basic dependencies with venv"
	@echo "venv_build_test - install testing dependencies with venv"
	@echo "venv_lint - check style with flake8 and mypy with venv"
	@echo "venv_test - run tests with venv"

clean:
	rm -rf venv/
	rm -rf build/
	rm -rf dist/
	rm -rf *.egg-info
	rm -rf .tox/
	find . -name __pycache__ -exec rm -rf {} \;
	find . -name .mypy_cache -exec rm -rf {} \;
	find . -name .pytest_cache -exec rm -rf {} \;

$(VENV_NAME)/bin/activate: requirements.txt
	@test -d $(VENV_NAME) || python3 -m venv --clear $(VENV_NAME)
	${VENV_NAME}/bin/python -m pip install -r requirements.txt
	${VENV_NAME}/bin/python -m pip install -r requirements_test.txt
	${VENV_NAME}/bin/python setup.py install
	@touch $(VENV_NAME)/bin/activate

venv_build: $(VENV_NAME)/bin/activate

venv_build_test: venv_build
	${VENV_NAME}/bin/python -m pip install -r requirements_test.txt

venv_test: venv_build_test
	$(VENV_ACTIVATE) && python -m pytest ./tests

venv_lint: venv_build_test
	$(VENV_ACTIVATE) && flake8 --config=flake8.ini ./staking_deposit ./tests && mypy --config-file mypy.ini -p staking_deposit

venv_deposit: venv_build
	$(VENV_ACTIVATE) && python ./staking_deposit/deposit.py $(filter-out $@,$(MAKECMDGOALS))

build_macos: venv_build
	${VENV_NAME}/bin/python -m pip install -r ./build_configs/macos/requirements.txt
	export PYTHONHASHSEED=42; \
	$(VENV_ACTIVATE) && pyinstaller ./build_configs/macos/build.spec;

build_linux: venv_build
	${VENV_NAME}/bin/python -m pip install -r ./build_configs/linux/requirements.txt
	export PYTHONHASHSEED=42; \
	$(VENV_ACTIVATE) && pyinstaller ./build_configs/linux/build.spec


build_docker:
	@docker build --pull -t $(DOCKER_IMAGE) .

run_docker:
	@docker run -it --rm $(DOCKER_IMAGE) $(filter-out $@,$(MAKECMDGOALS))

prepare_release: venv_test venv_lint
	@echo "准备发布版本，确保已更新版本号"

release: prepare_release build_macos build_linux build_docker
	@echo "所有平台构建完成，现在可以手动创建 GitHub Release 并上传相关文件"


# 记录, 复制到命令行执行 {"data":{"genesis_time":"1745394023","genesis_validators_root":"0xbf1a837d0321cb39db467151955b34bafc564bd8e8fdb3aed4697845d5c98136","genesis_fork_version":"0x20000089"}}
export-custom-env:
	export CUSTOM_GENESIS_VALIDATORS_ROOT=bf1a837d0321cb39db467151955b34bafc564bd8e8fdb3aed4697845d5c98136
	export CUSTOM_GENESIS_FORK_VERSION=20000089
	export CUSTOM_NETWORK_NAME=Weber
	# echo "CUSTOM_GENESIS_VALIDATORS_ROOT: $CUSTOM_GENESIS_VALIDATORS_ROOT"
	# echo "CUSTOM_GENESIS_FORK_VERSION: $(CUSTOM_GENESIS_FORK_VERSION)"
	# echo "CUSTOM_NETWORK_NAME: $(CUSTOM_NETWORK_NAME)"


existing-mnemonic:
	docker run -it -v $(pwd)/validator_keys:/app/validator_keys \
	-e CUSTOM_GENESIS_VALIDATORS_ROOT=bf1a837d0321cb39db467151955b34bafc564bd8e8fdb3aed4697845d5c98136 \
	-e CUSTOM_GENESIS_FORK_VERSION=20000089 \
	-e CUSTOM_NETWORK_NAME=Weber \
	ethereum/staking-deposit-cli:latest existing-mnemonic --num_validators=1 --chain=custom  --eth1_withdrawal_address=0x6038b38D1435C45b527A47c9b31f29f181F5Cc12


uv_run_deposit:
	# 虚拟环境
	uv venv
	source $(VENV_NAME)/bin/activate
	# py版本
	uv venv --python 3.12.0
	uv pip install ./build_configs/linux/requirements.txt
	export PYTHONPATH=$(pwd)
	python3 ./staking_deposit/deposit.py existing-mnemonic --num_validators=1 --chain=custom  --eth1_withdrawal_address=0x6038b38D1435C45b527A47c9b31f29f181F5Cc12


