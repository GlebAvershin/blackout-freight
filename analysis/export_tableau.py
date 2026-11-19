"""Export validated FirstShiftCompassV1 counts for Tableau and read them back."""
import argparse
import tempfile
from pathlib import Path

from tableauhyperapi import Connection, CreateMode, HyperProcess, Inserter, SqlType, TableDefinition, TableName, Telemetry

from compass_report import FIXTURE, SOURCES, read_counts


def export(counts_file, destination, source):
    if destination.suffix.lower() != ".hyper" or destination.resolve() == counts_file.resolve():
        raise ValueError("Choose a separate .hyper output file")
    if source not in SOURCES or (counts_file.resolve() == FIXTURE.resolve() and source != "synthetic"):
        raise ValueError("Label the bundled demonstration data as synthetic")
    counts = read_counts(counts_file)
    rows = sorted((source, *key, value) for key, value in counts.items())
    table = TableDefinition(TableName("Extract", "Extract"), [
        *(TableDefinition.Column(name, SqlType.text()) for name in ("source", "segment", "variant", "event")),
        TableDefinition.Column("events", SqlType.int()),
    ])
    with tempfile.TemporaryDirectory(dir=destination.parent) as staging:
        candidate = Path(staging) / "compass.hyper"
        with HyperProcess(Telemetry.DO_NOT_SEND_USAGE_DATA_TO_TABLEAU,
                          parameters={"log_dir": staging}) as engine:
            with Connection(engine.endpoint, candidate, CreateMode.CREATE) as db:
                db.catalog.create_schema("Extract")
                db.catalog.create_table(table)
                with Inserter(db, table) as insert:
                    insert.add_rows(rows)
                    insert.execute()
            with Connection(engine.endpoint, candidate) as db:
                restored = db.execute_list_query(f"SELECT * FROM {table.table_name}")
                if sorted(tuple(row) for row in restored) != rows:
                    raise ValueError("Extract differs from validated counts")
        candidate.replace(destination)
    return len(rows)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("counts", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--source", choices=SOURCES, required=True)
    args = parser.parse_args()
    print(f"{export(args.counts, args.output, args.source)} verified rows in {args.output}")
