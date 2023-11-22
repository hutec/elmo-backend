"""Add route limit

Revision ID: 99584cbcbf06
Revises: 
Create Date: 2023-11-19 17:16:26.450943

"""
from typing import Sequence, Union

import polyline
import sqlalchemy as sa
from sqlalchemy import text

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "99584cbcbf06"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def compute_bounds(route: Sequence[Sequence[float]]) -> Sequence[float]:
    """Compute the bounds of a route.

    Args:
        route: A list of lat/lon pairs.

    Returns:
        A string representing the bounds of the route.
    """
    lats = [lat for lat, _ in route]
    lons = [lon for _, lon in route]

    if lats == [] or lons == []:
        return ""

    return f"{min(lats)},{min(lons)},{max(lats)},{max(lons)}"


def upgrade():
    # Read the route column from the route table
    # decode with polyline and compute the bounds
    # store the bounds in the route table
    op.add_column("route", sa.Column("bounds", sa.String(1000), nullable=True))
    routes = op.get_bind().execute(text("SELECT id, route FROM route")).fetchall()

    for route in routes:
        route_id, encoded_route = route
        decoded_route = polyline.decode(encoded_route)
        bounds = compute_bounds(decoded_route)

        # Store the bounds in the bounds column of the route table
        op.execute(
            text("UPDATE route SET bounds = :bounds WHERE id = :route_id").params(
                bounds=bounds,
                route_id=route_id,
            )
        )


def downgrade():
    # Remove the bounds column from the route table
    op.drop_column("route", "bounds")
