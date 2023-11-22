import sys
import toml

def extract_faucet_values(toml_data):
    faucet_key = toml_data.get('keys', {}).get('faucet')
    faucet_addresses = toml_data.get('addresses', {}).get('faucet')

    pkhs = toml_data.get('pkhs', {})
    faucet_pkhs = next((address for address, name in pkhs.items() if name == 'faucet'), None)

    return faucet_key, faucet_addresses, faucet_pkhs


def write_faucet_values(toml_data, faucet_key, faucet_addresses, faucet_pkhs):
    toml_data['keys']['faucet'] = faucet_key
    toml_data['addresses']['faucet'] = faucet_addresses
    toml_data['pkhs'][faucet_pkhs] = 'faucet'

if __name__ == "__main__":
    dest_toml_path = sys.argv[1]

    with open('/root/.namada-shared/wallet-setup.toml', 'r') as file:
        toml_source = toml.load(file)
    with open(dest_toml_path, 'r') as file:
        toml_dest = toml.load(file)

    faucet_key, faucet_addresses, faucet_pkhs = extract_faucet_values(toml_source)
    write_faucet_values(toml_dest, faucet_key, faucet_addresses, faucet_pkhs)

    print("Faucet Key:", faucet_key)
    print("Faucet Addresses:", faucet_addresses)
    print("Faucet PKHS:", faucet_pkhs)

    with open(dest_toml_path, 'w') as file:
        toml.dump(toml_dest, file)
