"""new game architecture: soldiers, food, home coords, new buildings

Revision ID: 001
Revises:
Create Date: 2026-05-11
"""
from alembic import op
import sqlalchemy as sa

revision = '001'
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    # users tablosuna home koordinatları ve power_score ekle
    op.add_column('users', sa.Column('home_x', sa.Integer(), nullable=True))
    op.add_column('users', sa.Column('home_y', sa.Integer(), nullable=True))
    op.add_column('users', sa.Column('power_score', sa.Float(), nullable=True, server_default='0.0'))

    # player_resources tablosuna food enum değeri eklemek için
    # PostgreSQL'de enum değeri ekleme
    op.execute("ALTER TYPE resourcetype ADD VALUE IF NOT EXISTS 'food'")

    # buildings tablosunu güncelle (defense_contribution ekle, resource_type String yap)
    op.add_column('buildings', sa.Column('defense_contribution', sa.Float(), nullable=True, server_default='0.0'))
    # resource_type sütununu String'e çevir (nullable yaparak)
    try:
        op.alter_column('buildings', 'resource_type',
                        existing_type=sa.Enum('gold', 'wood', 'stone', 'iron', name='resourcetype'),
                        type_=sa.String(50),
                        existing_nullable=False,
                        nullable=True)
    except Exception:
        pass  # Zaten String ise geç

    # player_soldiers tablosu oluştur
    op.create_table(
        'player_soldiers',
        sa.Column('id', sa.String(), nullable=False),
        sa.Column('user_id', sa.String(), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('soldier_type', sa.Enum('swordsman', 'archer', 'knight', 'catapult', name='soldiertype'), nullable=False),
        sa.Column('count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_player_soldiers_user_id', 'player_soldiers', ['user_id'])


def downgrade():
    op.drop_index('ix_player_soldiers_user_id', 'player_soldiers')
    op.drop_table('player_soldiers')
    op.drop_column('buildings', 'defense_contribution')
    op.drop_column('users', 'power_score')
    op.drop_column('users', 'home_y')
    op.drop_column('users', 'home_x')
