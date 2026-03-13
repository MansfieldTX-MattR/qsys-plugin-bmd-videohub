from typing import TypedDict, NamedTuple, Self
from pathlib import Path
from string import Template
from xml.etree import ElementTree
from packaging.version import Version

import click
from luaparser import ast
from luaparser import astnodes

HERE = Path(__file__).parent
PROJECT_ROOT = HERE.parent
LUA_INFO_FILE = PROJECT_ROOT / "info.lua"
NUSPEC_FILE = PROJECT_ROOT / "package.nuspec"


class PluginInfoTD(TypedDict):
    Name: str
    PrettyName: str
    Version: str
    BuildVersion: str
    Id: str
    Author: str
    Description: str
    Color: list[int]

_PluginInfoTemplate = Template("""PluginInfo = {
    Name = "$Name",
    PrettyName = "$PrettyName",
    Version = "$Version",
    BuildVersion = "$BuildVersion",
    Id = "$Id",
    Author = "$Author",
    Description = "$Description",
    Color = {$Color},
}
""")

class PluginInfo(NamedTuple):
    """Typed version of the PluginInfo table as defined in info.lua

    This uses the Version class from the packaging library for the
    Version and BuildVersion fields, which allows for easy comparison and
    manipulation of version numbers.
    """
    Name: str
    PrettyName: str
    Version: Version
    BuildVersion: Version
    Id: str
    Author: str
    Description: str
    Color: list[int]

    @classmethod
    def from_dict(cls, data: PluginInfoTD) -> Self:
        """Create a PluginInfo instance from a PluginInfoTD dictionary,
        converting the Version and BuildVersion fields to Version objects.
        """
        return cls(
            Name=data["Name"],
            PrettyName=data["PrettyName"],
            Version=Version(data["Version"]),
            BuildVersion=Version(data["BuildVersion"]),
            Id=data["Id"],
            Author=data["Author"],
            Description=data["Description"],
            Color=data["Color"]
        )

    @property
    def full_version(self) -> Version:
        """The combination of the Version and BuildVersion fields, formatted as
        `<Version>+build.<BuildVersion>`
        """
        return Version(f"{self.Version}+build.{self.BuildVersion}")

    def to_lua(self) -> str:
        """Convert the PluginInfo instance back to a Lua table string
        """
        color_str = ", ".join(str(c) for c in self.Color)
        color_str = f' {color_str} '
        return _PluginInfoTemplate.substitute(
            Name=self.Name,
            PrettyName=self.PrettyName,
            Version=str(self.Version),
            BuildVersion=str(self.BuildVersion),
            Id=self.Id,
            Author=self.Author,
            Description=self.Description,
            Color=color_str
        )




def get_plugin_info(info_file: Path = LUA_INFO_FILE) -> PluginInfo:
    """Parse the info.lua file and return a PluginInfo instance with the data
    """
    def visit_Table(node: astnodes.Table) -> str|int|dict|list:
        fields = node.fields
        is_list = all(isinstance(field, astnodes.Field) and field.key is None for field in fields)
        if is_list:
            return visit_list_Table(node)
        return visit_dict_Table(node)

    def visit_list_Table(node: astnodes.Table) -> list[str|int|dict|list]:
        result = []
        for field in node.fields:
            if not isinstance(field, astnodes.Field) or field.key is not None:
                raise ValueError("Expected list field with no key")
            result.append(visit_list_Field(field))
        return result

    def visit_dict_Table(node: astnodes.Table) -> dict[str, str|int|dict|list]:
        result = {}
        for field in node.fields:
            if not isinstance(field, astnodes.Field) or field.key is None:
                raise ValueError("Expected dict field with a key")
            field_name, field_value = visit_dict_Field(field)
            result[field_name] = field_value
        return result

    def visit_list_Field(node: astnodes.Field) -> str|int:
        if isinstance(node.value, astnodes.String):
            return node.value.s.decode("utf-8")
        elif isinstance(node.value, astnodes.Number):
            return node.value.n
        else:
            raise ValueError(f"Unsupported list field value type: {type(node.value)}")

    def visit_dict_Field(node: astnodes.Field) -> tuple[str, str|int|dict|list]:
        assert isinstance(node.key, astnodes.Name)
        field_name = node.key.id
        if isinstance(node.value, astnodes.String):
            field_value = node.value.s.decode("utf-8")
        elif isinstance(node.value, astnodes.Number):
            field_value = node.value.n
        elif isinstance(node.value, astnodes.Table):
            field_value = visit_Table(node.value)
        else:
            raise ValueError(f"Unsupported field value type: {type(node.value)}")
        return field_name, field_value


    def visit_Assign(node: astnodes.Assign):
        if len(node.targets) != 1:
            return None
        name_target = node.targets[0]
        if not isinstance(name_target, astnodes.Name):
            return None
        if name_target.id != "PluginInfo":
            return None
        assert len(node.values) == 1
        assert isinstance(node.values[0], astnodes.Table)
        table_node = node.values[0]
        return visit_Table(table_node)

    def parse() -> PluginInfoTD:
        with open(info_file, "r") as f:
            lua_code = f.read()
        tree = ast.parse(lua_code)
        for node in ast.walk(tree):
            if isinstance(node, astnodes.Assign):
                plugin_info = visit_Assign(node)
                if plugin_info is not None:
                    assert isinstance(plugin_info, dict)
                    return PluginInfoTD(**plugin_info)
        raise ValueError("PluginInfo not found in Lua file")
    info_dict = parse()
    return PluginInfo.from_dict(info_dict)


def update_nuspec_version(plugin_info: PluginInfo, nuspec_file: Path = NUSPEC_FILE):
    """Update the version, author, and description fields in the package.nuspec file
    with the values from the PluginInfo instance
    """
    xmlns = "http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd"
    ElementTree.register_namespace("", xmlns)
    tree = ElementTree.parse(nuspec_file)
    root = tree.getroot()
    def ns_tag(tag: str) -> str:
        return f"{{{xmlns}}}{tag}"

    version_elem = root.find(f".//{ns_tag('metadata')}/{ns_tag('version')}")
    assert version_elem is not None, "version element not found in nuspec file"
    version_elem.text = str(plugin_info.Version)
    author_elem = root.find(f".//{ns_tag('metadata')}/{ns_tag('authors')}")
    assert author_elem is not None, "authors element not found in nuspec file"
    author_elem.text = plugin_info.Author
    description_elem = root.find(f".//{ns_tag('metadata')}/{ns_tag('description')}")
    assert description_elem is not None, "description element not found in nuspec file"
    description_elem.text = plugin_info.Description

    tree.write(nuspec_file, encoding="utf-8", xml_declaration=True)


@click.group()
def cli():
    pass

@cli.command()
@click.option(
    "--full",
    is_flag=True,
    help="Print the full version including build version (e.g. 1.0.0+build.1)"
)
def get_plugin_version(full: bool):
    """Get the full version of the plugin

    >>> python update_nuspec_from_info.py get-plugin-version
    1.0.0

    >>> python update_nuspec_from_info.py get-plugin-version --full
    1.0.0+build.1

    """
    plugin_info = get_plugin_info()
    v = plugin_info.full_version if full else plugin_info.Version
    click.echo(v)


@cli.command()
def get_nuspec_version():
    """Get the version field from the package.nuspec file

    >>> python update_nuspec_from_info.py get-nuspec-version
    1.0.0

    """
    xmlns = "http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd"
    ElementTree.register_namespace("", xmlns)
    tree = ElementTree.parse(NUSPEC_FILE)
    root = tree.getroot()
    def ns_tag(tag: str) -> str:
        return f"{{{xmlns}}}{tag}"
    version_elem = root.find(f".//{ns_tag('metadata')}/{ns_tag('version')}")
    assert version_elem is not None, "version element not found in nuspec file"
    click.echo(version_elem.text)


@cli.command()
def update_nuspec():
    """Update the version, author, and description fields in the package.nuspec file
    with the values from the PluginInfo instance
    """
    plugin_info = get_plugin_info()
    update_nuspec_version(plugin_info)



if __name__ == "__main__":
    cli()
