## Usage

```shell
mkdir ~/devel/opensource/
cd ~/devel/opensource
git clone https://github.com/pingcap/pd.git
git clone https://github.com/tikv/copr-test.git
git clone https://github.com/tikv/tikv.git

cd ~/devel/opensource/pd
make

cd ~/devel/opensource/tikv
make

cd ~/devel/opensource/copr-test
pd_bin=~/devel/opensource/pd/bin/pd-server tikv_bin=~/devel/opensource/tikv/target/release/tikv-server make push-down-test
```
